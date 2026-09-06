<?php

namespace App\AI\Services;

use App\AI\Contracts\LLMProvider;
use App\Models\ProjectMemory;
use Illuminate\Support\Facades\Log;

/**
 * ProjectMemoryService — manages AI-extracted persistent project facts.
 *
 * Design principles:
 *  - Memory extraction is LLM-driven (structured output), NOT keyword-based.
 *  - Extraction happens asynchronously AFTER the main AI response is sent.
 *  - Extraction failure NEVER blocks AI execution.
 *  - Retrieval is structured (by importance/type), NOT semantic vector search.
 *  - Only data that is explicitly project-wide and long-lived is stored.
 */
class ProjectMemoryService
{
    // Keys that should never be stored (security)
    private const FORBIDDEN_KEY_PATTERNS = ['token', 'password', 'key', 'secret', 'credential', 'api_key'];

    // ─────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────

    /**
     * Upsert a single memory entry for a project.
     *
     * Performs conflict resolution: same (project_id, key) → update.
     * Does NOT store sensitive keys (see FORBIDDEN_KEY_PATTERNS).
     */
    public function upsert(
        int     $projectId,
        string  $key,
        string  $value,
        string  $type,
        string  $importance,
        ?int    $sourceConversationId = null
    ): ?ProjectMemory {
        // Sanitize key
        $key = strtolower(trim($key));

        if (!$this->isKeyAllowed($key)) {
            Log::warning('[Memory] Blocked attempt to store sensitive key', ['key' => $key]);
            return null;
        }

        if (!in_array($type, ProjectMemory::allowedTypes())) {
            $type = 'project_fact';
        }

        if (!in_array($importance, ProjectMemory::allowedImportance())) {
            $importance = 'medium';
        }

        return ProjectMemory::upsertMemory(
            $projectId, $key, $value, $type, $importance, $sourceConversationId
        );
    }

    /**
     * Get relevant memories for a project, filtered by importance.
     *
     * This is NOT a semantic/vector search.
     * Returns high+medium importance memories ordered by importance DESC.
     * The LLM already injects detailed context — memories are supplementary.
     *
     * @param  int    $projectId
     * @param  array  $filters   e.g. ['type' => 'preference'] — optional
     * @param  int    $limit     max records (default: from config)
     * @return array
     */
    public function getRelevant(int $projectId, array $filters = [], int $limit = 0): array
    {
        $limit = $limit > 0 ? $limit : config('ai.context.max_memories', 10);

        $query = ProjectMemory::forProject($projectId)->relevant();

        if (!empty($filters['type'])) {
            $query->where('type', $filters['type']);
        }

        return $query
            ->byImportance()
            ->limit($limit)
            ->get(['key', 'value', 'type', 'importance'])
            ->toArray();
    }

    /**
     * Extract project memories from an AI exchange using LLM structured output.
     *
     * Called AFTER the main AI response is saved. Completely non-blocking —
     * any exception is caught and logged, never propagated.
     *
     * The LLM decides what (if anything) is worth storing as project memory.
     * No keyword heuristics involved.
     */
    public function extractFromAssistantResponse(
        int         $projectId,
        int         $conversationId,
        string      $userMessage,
        string      $assistantResponse,
        LLMProvider $llm
    ): void {
        try {
            $schema   = $this->getMemoryExtractionSchema();
            $messages = $this->buildExtractionMessages($userMessage, $assistantResponse);

            $result = $llm->chat($messages, $schema);

            if (empty($result['should_store']) || !is_array($result['memories'] ?? null)) {
                return;
            }

            foreach ($result['memories'] as $candidate) {
                if (!$this->isValidCandidate($candidate)) {
                    continue;
                }

                $this->upsert(
                    $projectId,
                    $candidate['key'],
                    $candidate['value'],
                    $candidate['type']       ?? 'project_fact',
                    $candidate['importance'] ?? 'medium',
                    $conversationId
                );
            }
        } catch (\Throwable $e) {
            // Non-fatal — only log, never rethrow
            Log::warning('[Memory] Extraction failed (non-fatal)', [
                'project_id' => $projectId,
                'error'      => $e->getMessage(),
            ]);
        }
    }

    // ─────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────

    private function isKeyAllowed(string $key): bool
    {
        foreach (self::FORBIDDEN_KEY_PATTERNS as $pattern) {
            if (str_contains($key, $pattern)) {
                return false;
            }
        }
        return true;
    }

    private function isValidCandidate(array $candidate): bool
    {
        return !empty($candidate['key'])
            && !empty($candidate['value'])
            && is_string($candidate['key'])
            && is_string($candidate['value'])
            && strlen($candidate['key']) <= 100
            && strlen($candidate['value']) <= 2000;
    }

    /**
     * Build LLM messages for memory extraction.
     *
     * We ask the LLM a focused question: "Is there anything in this exchange
     * that should be stored as a long-term project fact?"
     *
     * Only project-wide, persistent, future-useful information qualifies.
     * Transient instructions (e.g., "make this button blue") do NOT qualify.
     */
    private function buildExtractionMessages(string $userMessage, string $assistantResponse): array
    {
        $systemPrompt = <<<PROMPT
You are a Memory Extraction Agent for an AI-powered app builder.

Your task: determine if the following AI conversation turn contains information that should be stored as a persistent project-level fact.

## Store memory ONLY when the information is:
1. Long-lived (not a one-time instruction)
2. Project-wide in scope (affects the whole project, not just one element)
3. Explicitly stated by the user as a general preference or rule
4. Useful for future AI requests in this same project

## Do NOT store:
- One-time widget modifications ("make this button blue")
- Temporary instructions
- Navigation actions
- Delete actions
- Anything that refers to a single specific element without a project-wide implication
- Personal/sensitive data

## Memory types:
- preference: User style/UX preference for the project (e.g., dark theme, RTL language)
- design_rule: A design rule that applies to the whole project
- project_fact: A factual fact about the project (e.g., app name, primary purpose)
- ui_fact: A UI-level fact about the project structure
- technical_constraint: A technical requirement that affects AI decisions

## Importance levels:
- high: Affects many future AI decisions
- medium: Moderately useful for future context
- low: Minor background fact

Respond ONLY with a JSON object.
PROMPT;

        return [
            ['role' => 'system', 'content' => $systemPrompt],
            ['role' => 'user', 'content' => "User said: \"{$userMessage}\"\n\nAI responded: \"{$assistantResponse}\""],
        ];
    }

    /**
     * JSON Schema for LLM memory extraction output.
     */
    private function getMemoryExtractionSchema(): array
    {
        return [
            'type'       => 'object',
            'required'   => ['should_store', 'memories'],
            'properties' => [
                'should_store' => [
                    'type'        => 'boolean',
                    'description' => 'True only if at least one project-level memory should be stored',
                ],
                'memories' => [
                    'type'  => 'array',
                    'items' => [
                        'type'       => 'object',
                        'required'   => ['key', 'value', 'type', 'importance'],
                        'properties' => [
                            'key' => [
                                'type'        => 'string',
                                'description' => 'Normalized dot-notation key, e.g. "theme.mode" or "app.language"',
                            ],
                            'value' => [
                                'type'        => 'string',
                                'description' => 'The memory value, e.g. "dark" or "arabic"',
                            ],
                            'type' => [
                                'type' => 'string',
                                'enum' => ['preference', 'design_rule', 'project_fact', 'ui_fact', 'technical_constraint'],
                            ],
                            'importance' => [
                                'type' => 'string',
                                'enum' => ['low', 'medium', 'high'],
                            ],
                            'reason' => [
                                'type'        => 'string',
                                'description' => 'Why this should be stored as a project memory',
                            ],
                        ],
                    ],
                ],
            ],
        ];
    }
}
