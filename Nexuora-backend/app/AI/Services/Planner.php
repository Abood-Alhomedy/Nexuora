<?php

namespace App\AI\Services;

use App\AI\Registry\ActionRegistry;

/**
 * Planner — converts an intent + resolved target into an ordered list
 * of ActionDescriptors that Flutter's AiActionExecutor will run.
 *
 * Key rules:
 *  - new_widget_id is ALWAYS null → Flutter generates via getWidgetId()
 *  - For complex intents (CREATE_SCREEN) the plan may contain multiple steps
 *  - For CREATE_APP: always requires_confirmation = true
 */
class Planner
{
    /**
     * Build an ordered list of ActionDescriptors.
     *
     * @param  array  $intentResult  from IntentAnalyzer
     * @param  array  $targetResult  from TargetResolver
     * @param  array  $context       from ContextBuilder
     * @return array  { action_descriptors: array, requires_confirmation: bool, plan_preview: string }
     */
    public function plan(array $intentResult, array $targetResult, array $context): array
    {
        $intent     = $intentResult['intent'];
        $params     = $intentResult['parameters'] ?? [];
        $widgetId   = $targetResult['widget_id'] ?? null;

        $requiresConfirmation = $intentResult['requires_confirmation']
            ?? ActionRegistry::requiresConfirmation($intent);

        switch ($intent) {
            case 'ADD_WIDGET':
                return $this->planAddWidget($params, $targetResult, $context, $requiresConfirmation);

            case 'UPDATE_WIDGET':
            case 'UPDATE_PROPERTY':
            case 'UPDATE_STYLE':
                return $this->planUpdateWidget($widgetId, $params, $requiresConfirmation);

            case 'DELETE_WIDGET':
                return $this->planDeleteWidget($widgetId, $requiresConfirmation);

            case 'MOVE_WIDGET':
                return $this->planMoveWidget($widgetId, $params, $requiresConfirmation);

            case 'DUPLICATE_WIDGET':
                return $this->planDuplicateWidget($widgetId, $requiresConfirmation);

            case 'CREATE_SCREEN':
                return $this->planCreateScreen($params, $requiresConfirmation);

            case 'DELETE_SCREEN':
                $screenId = $targetResult['widget_id'] ?? $params['screen_id'] ?? null;
                return $this->planDeleteScreen($screenId, $requiresConfirmation);

            case 'RENAME_SCREEN':
                $screenId = $params['screen_id'] ?? null;
                return $this->planRenameScreen($screenId, $params, $requiresConfirmation);

            case 'ADD_NAVIGATION':
                return $this->planAddNavigation($widgetId, $params, $context, $requiresConfirmation);

            case 'REMOVE_NAVIGATION':
                return $this->planRemoveNavigation($widgetId, $requiresConfirmation);

            case 'UPDATE_THEME':
                return $this->planUpdateTheme($params, $requiresConfirmation);

            default:
                return [
                    'action_descriptors'  => [],
                    'requires_confirmation' => false,
                    'plan_preview'        => 'I cannot generate a plan for this intent: ' . $intent,
                ];
        }
    }

    // ─────────────────────────────────────────────────────────
    // Action plan builders
    // ─────────────────────────────────────────────────────────

private function planAddWidget(
    array $params,
    array $targetResult,
    array $context,
    bool $confirm
): array {
    $widgetType = $params['widget_type'] ?? 'Container';

    $parentId = $targetResult['widget_id']
        ?? $context['ui_context']['current_parent_widget_id']
        ?? null;

    /*
     * Build defaults from direct parameters first.
     * Then merge explicit properties on top of them.
     *
     * This is important because properties may exist as an empty
     * array while the actual text/value is present directly in params.
     */
    $properties = $this->getDefaultProperties($widgetType, $params);

    if (!empty($params['properties']) && is_array($params['properties'])) {
        $properties = array_merge($properties, $params['properties']);
    }

    $descriptor = [
        'action_id' => 'a1',
        'type' => 'ADD_WIDGET',

        'target' => [
            'parent_id' => $parentId,
        ],

        'payload' => [
            'widget_type' => $widgetType,
            'properties' => $properties,
            'new_widget_id' => null,
        ],
    ];

    return [
        'action_descriptors' => [$descriptor],

        'requires_confirmation' => $confirm,

        'plan_preview' =>
            "Add a {$widgetType} widget"
            . ($parentId ? " inside the selected container" : ""),
    ];
}

    private function planUpdateWidget(?string $widgetId, array $params, bool $confirm): array
    {
        $properties = $params['properties'] ?? $params['style_properties'] ?? [];

        // Handle direct property params (e.g., "backgroundColor" => "#FF0000")
        if (empty($properties)) {
            $directProps = array_diff_key($params, array_flip(['widget_type', 'widget_id']));
            $properties  = $directProps;
        }

        return [
            'action_descriptors' => [[
                'action_id' => 'a1',
                'type'      => 'UPDATE_WIDGET',
                'target'    => ['widget_id' => $widgetId],
                'payload'   => ['properties' => $properties],
            ]],
            'requires_confirmation' => $confirm,
            'plan_preview'         => 'Update widget properties: ' . implode(', ', array_keys($properties)),
        ];
    }

    private function planDeleteWidget(?string $widgetId, bool $confirm): array
    {
        return [
            'action_descriptors' => [[
                'action_id' => 'a1',
                'type'      => 'DELETE_WIDGET',
                'target'    => ['widget_id' => $widgetId],
                'payload'   => [],
            ]],
            'requires_confirmation' => true, // always confirmed for delete
            'plan_preview'         => 'Delete the selected widget and its children',
        ];
    }

    private function planMoveWidget(?string $widgetId, array $params, bool $confirm): array
    {
        $direction = $params['direction'] ?? 'up';
        return [
            'action_descriptors' => [[
                'action_id' => 'a1',
                'type'      => 'MOVE_WIDGET',
                'target'    => ['widget_id' => $widgetId],
                'payload'   => ['direction' => $direction],
            ]],
            'requires_confirmation' => $confirm,
            'plan_preview'         => "Move widget {$direction}",
        ];
    }

    private function planDuplicateWidget(?string $widgetId, bool $confirm): array
    {
        return [
            'action_descriptors' => [[
                'action_id' => 'a1',
                'type'      => 'DUPLICATE_WIDGET',
                'target'    => ['widget_id' => $widgetId],
                'payload'   => ['new_widget_id' => null], // Flutter generates
            ]],
            'requires_confirmation' => $confirm,
            'plan_preview'         => 'Duplicate the selected widget',
        ];
    }

    private function planCreateScreen(array $params, bool $confirm): array
    {
        $screenName = $params['screen_name'] ?? 'New Screen';

        // A basic screen = Scaffold + Column (2 actions)
        $descriptors = [
            [
                'action_id' => 'a1',
                'type'      => 'CREATE_SCREEN',
                'target'    => [],
                'payload'   => [
                    'screen_name'   => $screenName,
                    'new_screen_id' => null, // Backend creates, returns real ID
                ],
            ],
        ];

        // Optionally add initial widgets if requested
        if (!empty($params['initial_widgets'])) {
            foreach ($params['initial_widgets'] as $i => $widgetSpec) {
                $descriptors[] = [
                    'action_id' => 'a' . ($i + 2),
                    'type'      => 'ADD_WIDGET',
                    'target'    => ['parent_id' => 'a1_scaffold_ref'], // symbolic
                    'payload'   => [
                        'widget_type'   => $widgetSpec['widget_type'] ?? 'Column',
                        'properties'    => $widgetSpec['properties'] ?? [],
                        'new_widget_id' => null,
                    ],
                ];
            }
        }

        return [
            'action_descriptors'   => $descriptors,
            'requires_confirmation' => $confirm,
            'plan_preview'         => "Create new screen: '{$screenName}'",
        ];
    }

    private function planDeleteScreen(?string $screenId, bool $confirm): array
    {
        return [
            'action_descriptors' => [[
                'action_id' => 'a1',
                'type'      => 'DELETE_SCREEN',
                'target'    => ['screen_id' => $screenId],
                'payload'   => [],
            ]],
            'requires_confirmation' => true, // always confirmed
            'plan_preview'         => 'Delete screen and all its widgets — this cannot be undone',
        ];
    }

    private function planRenameScreen(?string $screenId, array $params, bool $confirm): array
    {
        return [
            'action_descriptors' => [[
                'action_id' => 'a1',
                'type'      => 'RENAME_SCREEN',
                'target'    => ['screen_id' => $screenId],
                'payload'   => ['new_name' => $params['new_name'] ?? ''],
            ]],
            'requires_confirmation' => $confirm,
            'plan_preview'         => "Rename screen to '{$params['new_name']}'",
        ];
    }

    private function planAddNavigation(?string $widgetId, array $params, array $context, bool $confirm): array
    {
        // Navigation is achieved by setting the widget's onPressed property
        // No new navigation engine — uses existing widget property system
        $destScreen = $params['destination_screen_name'] ?? $params['screen_name'] ?? '';
        return [
            'action_descriptors' => [[
                'action_id' => 'a1',
                'type'      => 'ADD_NAVIGATION',
                'target'    => ['widget_id' => $widgetId],
                'payload'   => [
                    'destination_screen_name' => $destScreen,
                    'navigation_type'         => $params['navigation_type'] ?? 'push',
                ],
            ]],
            'requires_confirmation' => $confirm,
            'plan_preview'         => "Add navigation to '{$destScreen}' on button tap",
        ];
    }

    private function planRemoveNavigation(?string $widgetId, bool $confirm): array
    {
        return [
            'action_descriptors' => [[
                'action_id' => 'a1',
                'type'      => 'REMOVE_NAVIGATION',
                'target'    => ['widget_id' => $widgetId],
                'payload'   => [],
            ]],
            'requires_confirmation' => $confirm,
            'plan_preview'         => 'Remove navigation action from widget',
        ];
    }

    private function planUpdateTheme(array $params, bool $confirm): array
    {
        return [
            'action_descriptors' => [[
                'action_id' => 'a1',
                'type'      => 'UPDATE_THEME',
                'target'    => [],
                'payload'   => ['theme_properties' => $params['theme_properties'] ?? $params],
            ]],
            'requires_confirmation' => $confirm,
            'plan_preview'         => 'Update app theme',
        ];
    }

    /**
     * Get sensible default properties for a widget type based on LLM params.
     */
private function getDefaultProperties(string $widgetType, array $params): array
{
    $normalizedType = strtolower(trim($widgetType));

    return match ($normalizedType) {

        'text' => [
            'text' =>
                $params['text']
                ?? $params['label']
                ?? $params['title_text']
                ?? 'Text',
        ],

        'button',
        'textbutton' => [
            'text' =>
                $params['text']
                ?? $params['label']
                ?? $params['title_text']
                ?? 'Button',
        ],

        'appbar' => [
            'title' =>
                $params['title']
                ?? $params['text']
                ?? $params['title_text']
                ?? '',
        ],

        'textfield' => [
            'hintText' =>
                $params['hintText']
                ?? $params['hint']
                ?? 'Enter text',
        ],

        'sizedbox' => [
            'height' => $params['height'] ?? 16,
            'width' => $params['width'] ?? null,
        ],

        'divider' => [
            'thickness' => $params['thickness'] ?? 1,
        ],

        default => [],
    };
}
}
