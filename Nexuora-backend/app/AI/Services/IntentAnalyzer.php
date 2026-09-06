<?php

namespace App\AI\Services;

use App\AI\Contracts\LLMProvider;
use App\AI\Registry\ActionRegistry;
use App\AI\Registry\WidgetRegistry;

/**
 * IntentAnalyzer — determines intent from user message using LLM.
 *
 * Returns an IntentResult with:
 *   - intent:     one of 18 registered action types (or CLARIFY/UNKNOWN)
 *   - confidence: high | medium | low
 *   - target:     description of the target widget/screen
 *   - parameters: extracted parameters for the action
 *   - missing_parameters: list of parameters still needed
 *   - requires_confirmation: bool
 */
class IntentAnalyzer
{
    public function __construct(private LLMProvider $llm) {}

    public function analyze(string $userMessage, array $context, array $history = []): array
{
    $systemPrompt = $this->buildSystemPrompt($context);
    $messages     = $this->buildMessages($systemPrompt, $history, $userMessage);
    $schema       = $this->getIntentResultSchema();

    $result = $this->llm->chat($messages, $schema);

    // Normalize each task's parameters
    $tasks = $result['tasks'] ?? [];
    foreach ($tasks as &$task) {
        $task = $this->normalizeParameters($task);

        // Normalize confidence
        if (!in_array($task['confidence'] ?? '', ['high', 'medium', 'low'])) {
            $task['confidence'] = 'low';
        }

        // Add requires_confirmation from ActionRegistry if not set
        if (!isset($task['requires_confirmation'])) {
            $actionDef = ActionRegistry::get($task['intent'] ?? '');
            $task['requires_confirmation'] = $actionDef['requires_confirmation'] ?? false;
        }
    }
    unset($task);

    $result['tasks'] = $tasks;

    // Top-level fallback for clarification_question and plan_description
    if (!isset($result['clarification_question'])) {
        $result['clarification_question'] = null;
    }

    return $result;
}

    // ─────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────

    private function buildSystemPrompt(array $context): string
    {
        $actionList    = json_encode(ActionRegistry::getCompactList(), JSON_PRETTY_PRINT);
        $widgetSummary = json_encode(WidgetRegistry::getCompactSummary(), JSON_PRETTY_PRINT);
        $widgetIndex   = json_encode($context['widget_index'] ?? [], JSON_PRETTY_PRINT);
        $screenInfo    = json_encode([
            'current_screen' => $context['current_screen'] ?? null,
            'all_screens'    => $context['all_screens'] ?? [],
        ], JSON_PRETTY_PRINT);
        $uiContext     = json_encode($context['ui_context'] ?? [], JSON_PRETTY_PRINT);
        $convContext   = json_encode($context['conversation_context'] ?? [], JSON_PRETTY_PRINT);
        $projectMemory = json_encode($context['project_memory'] ?? [], JSON_PRETTY_PRINT);

        return <<<PROMPT
You are the Intent Analyzer for Nexuora — an AI-powered Flutter UI Builder.
Your job is to analyze the user's message and extract their intent for modifying a mobile app UI.

## Current State
### UI Context (from Flutter editor)
{$uiContext}

### Current Screen / Screens
{$screenInfo}

### Widget Tree Index (all widgets in current screen: id, type, label)
{$widgetIndex}

## Conversation Context (recent history + summary)
{$convContext}

## Project Memory (persistent project-level facts)
{$projectMemory}

## Priority Rules for Context
1. **UI Context (above) is ALWAYS highest priority** — the currently selected widget, current screen, etc.
2. **Widget Tree Index** — only use widget IDs that exist here.
3. **Conversation Context** — use to resolve references like "it", "the button", "the last element".
4. **Project Memory** — background facts about the project (theme, language, etc.).
   - Memory provides CONTEXT only — it does NOT trigger actions on its own.
   - Memory NEVER overrides what the user is explicitly asking for now.
   - If memory says selected_widget = X but UI says selected_widget = Y, use Y.

## Supported Actions
These are the ONLY valid intents you can return:
{$actionList}

You may also return:
- "CLARIFY" if the request is ambiguous and you need more information
- "UNKNOWN" if the request is not related to UI building

## Supported Widget Types
{$widgetSummary}

## Rules
1. confidence MUST be exactly "high", "medium", or "low" — nothing else.
2. intent MUST be one of the action types listed above (or CLARIFY/UNKNOWN).
3. target.widget_id: if the user said "the selected widget" or "this widget" and a widget is selected in ui_context, use its id. Otherwise leave null and describe it.
4. parameters: extract ONLY parameters you are confident about from the user message.
5. missing_parameters: list any additional information needed to execute the action.
6. never invent widget IDs — only use IDs from the widget_index above.
7. requires_confirmation: set true for DELETE_WIDGET, DELETE_SCREEN actions.
8. ALL color values (like backgroundColor, color) MUST be converted to valid hex codes (e.g. #FF0000). NEVER use color words like "red" or "احمر".
9. For ADD_WIDGET intent: ALL widget properties (text, label, backgroundColor, color, fontSize, etc.) that the user mentioned MUST be placed inside `parameters.properties` as a flat key-value object. Example: if user says "add a button with text 'delete' and gray background", set:
   parameters: {
     "widget_type": "Button",
     "properties": {
       "text": "delete",
       "backgroundColor": "#808080"
     }
   }

## JSON Output Schema
Respond with ONLY a JSON object matching this exact structure.

**CRITICAL:** If the user's message contains MULTIPLE tasks (e.g., "add a button AND set its color to red AND write 'delete' in it"), you MUST return ALL of them as separate items in the `tasks` array. Do NOT collapse them into one.
PROMPT;
    }

    private function buildMessages(string $systemPrompt, array $history, string $userMessage): array
    {
        $messages = [['role' => 'system', 'content' => $systemPrompt]];

        // Add recent conversation history (last 6 messages max)
        foreach (array_slice($history, -6) as $msg) {
            $messages[] = [
                'role'    => $msg['role'] === 'assistant' ? 'assistant' : 'user',
                'content' => $msg['content'],
            ];
        }

        $messages[] = ['role' => 'user', 'content' => $userMessage];
        return $messages;
    }

    private function getIntentResultSchema(): array
{
    $taskSchema = [
        'type' => 'object',
        'required' => ['intent', 'confidence', 'target', 'parameters', 'missing_parameters', 'requires_confirmation'],
        'properties' => [
            'intent' => [
                'type' => 'string',
                'description' => 'One of the registered action types, or CLARIFY, or UNKNOWN',
            ],
            'confidence' => [
                'type' => 'string',
                'enum' => ['high', 'medium', 'low'],
            ],
            'target' => [
                'type' => 'object',
                'properties' => [
                    'type'        => ['type' => 'string', 'enum' => ['widget', 'screen', 'project', 'none']],
                    'widget_id'   => ['type' => ['string', 'null']],
                    'description' => ['type' => 'string'],
                ],
            ],
            'parameters' => [
                'type' => 'object',
                'description' => 'Key-value pairs of extracted parameters for the action',
            ],
            'missing_parameters' => [
                'type' => 'array',
                'items' => ['type' => 'string'],
                'description' => 'Parameters still needed to execute the action',
            ],
            'requires_confirmation' => [
                'type' => 'boolean',
            ],
        ],
    ];

    return [
        'type' => 'object',
        'required' => ['tasks'],
        'properties' => [
            'tasks' => [
                'type' => 'array',
                'description' => 'List of all tasks extracted from the user message. Must have at least one item.',
                'items' => $taskSchema,
            ],
            'clarification_question' => [
                'type' => ['string', 'null'],
                'description' => 'Question to ask user when ALL tasks are CLARIFY or UNKNOWN',
            ],
            'plan_description' => [
                'type' => ['string', 'null'],
                'description' => 'Human-readable summary of all tasks that will be done',
            ],
        ],
    ];
}

    /**
 * Normalize parameters returned by the LLM.
 *
 * The LLM may return human-readable color names such as:
 *
 * green
 * red
 * blue
 * white
 * black
 *
 * The ActionValidator expects HEX colors.
 */
private function normalizeParameters(array $result): array
{
    if (!isset($result['parameters']) || !is_array($result['parameters'])) {
        return $result;
    }

    if (isset($result['parameters']['color'])) {
        $result['parameters']['color'] =
            $this->normalizeColor($result['parameters']['color']);
    }

    if (isset($result['parameters']['backgroundColor'])) {
        $result['parameters']['backgroundColor'] =
            $this->normalizeColor($result['parameters']['backgroundColor']);
    }

    if (isset($result['parameters']['textColor'])) {
        $result['parameters']['textColor'] =
            $this->normalizeColor($result['parameters']['textColor']);
    }

    // Also normalize colors inside properties sub-object (for ADD_WIDGET)
if (isset($result['parameters']['properties']) && is_array($result['parameters']['properties'])) {
    foreach (['color', 'backgroundColor', 'textColor'] as $colorKey) {
        if (isset($result['parameters']['properties'][$colorKey])) {
            $result['parameters']['properties'][$colorKey] =
                $this->normalizeColor($result['parameters']['properties'][$colorKey]);
        }
    }
}

    return $result;
}

/**
 * Convert common color names to HEX.
 */
private function normalizeColor(mixed $color): mixed
{
    if (!is_string($color)) {
        return $color;
    }

    $color = trim(strtolower($color));

    // Already HEX (6 or 8 chars)
    if (preg_match('/^#([0-9a-f]{6}|[0-9a-f]{8})$/i', $color)) {
        return strtoupper($color);
    }

    // HEX shorthand: #fff → #FFFFFF
    if (preg_match('/^#[0-9a-f]{3}$/i', $color)) {
        return strtoupper(
            '#' .
            $color[1] . $color[1] .
            $color[2] . $color[2] .
            $color[3] . $color[3]
        );
    }

    $colors = [

        // Basic
        'black'  => '#000000',
        'white'  => '#FFFFFF',
        'red'    => '#FF0000',
        'green'  => '#008000',
        'blue'   => '#0000FF',
        'yellow' => '#FFFF00',

        // Common UI colors
        'orange' => '#FFA500',
        'purple' => '#800080',
        'pink'   => '#FFC0CB',
        'brown'  => '#A52A2A',
        'gray'   => '#808080',
        'grey'   => '#808080',

        // Common variations
        'light green' => '#90EE90',
        'dark green'  => '#006400',

        'light blue' => '#ADD8E6',
        'dark blue'  => '#00008B',

        'light red' => '#FF7F7F',
        'dark red'  => '#8B0000',

        'light gray' => '#D3D3D3',
        'dark gray'  => '#404040',

        'cyan'   => '#00FFFF',
        'teal'   => '#008080',
        'lime'   => '#00FF00',
        'indigo' => '#4B0082',
        'violet' => '#EE82EE',
        'gold'   => '#FFD700',

        // Arabic Colors
        'احمر'    => '#FF0000',
        'أحمر'    => '#FF0000',
        'اخضر'   => '#008000',
        'أخضر'   => '#008000',
        'ازرق'    => '#0000FF',
        'أزرق'    => '#0000FF',
        'اصفر'   => '#FFFF00',
        'أصفر'   => '#FFFF00',
        'اسود'   => '#000000',
        'أسود'   => '#000000',
        'ابيض'   => '#FFFFFF',
        'أبيض'   => '#FFFFFF',
        'رمادي'  => '#808080',
        'برتقالي' => '#FFA500',
        'ارجواني' => '#800080',
        'وردي'   => '#FFC0CB',
        'بني'    => '#A52A2A',
        'سماوي'  => '#00FFFF',
    ];

    return $colors[$color] ?? $color;
}
}