<?php

namespace App\AI\Registry;

/**
 * ActionRegistry — closed set of allowed AI actions.
 *
 * The LLM can only produce actions from this list.
 * Each action has a schema, execution metadata, and safety flags.
 */
class ActionRegistry
{
    public static array $actions = [

        // ── Widget CRUD ──────────────────────────────────────────────
        'ADD_WIDGET' => [
            'description'          => 'Add a new widget to the screen',
            'requires_new_id'      => true,  // Flutter calls getWidgetId()
            'requires_confirmation'=> false,
            'reversible'           => true,
            'required_payload'     => ['widget_type'],
            'optional_payload'     => ['properties', 'parent_id'],
            'schema' => [
                'type' => 'object',
                'required' => ['type', 'target', 'payload'],
                'properties' => [
                    'type'    => ['type' => 'string', 'const' => 'ADD_WIDGET'],
                    'target'  => ['type' => 'object', 'properties' => ['parent_id' => ['type' => 'string']]],
                    'payload' => ['type' => 'object', 'required' => ['widget_type'],
                                  'properties' => ['widget_type' => ['type' => 'string'],
                                                   'properties'  => ['type' => 'object'],
                                                   'new_widget_id' => ['type' => 'null']]],
                ],
            ],
        ],

        'UPDATE_WIDGET' => [
            'description'          => 'Update properties of an existing widget',
            'requires_new_id'      => false,
            'requires_confirmation'=> false,
            'reversible'           => true,
            'required_payload'     => ['widget_id', 'properties'],
            'optional_payload'     => [],
            'schema' => [
                'type' => 'object',
                'required' => ['type', 'target', 'payload'],
                'properties' => [
                    'type'    => ['type' => 'string', 'const' => 'UPDATE_WIDGET'],
                    'target'  => ['type' => 'object', 'required' => ['widget_id'],
                                  'properties' => ['widget_id' => ['type' => 'string']]],
                    'payload' => ['type' => 'object', 'required' => ['properties'],
                                  'properties' => ['properties' => ['type' => 'object']]],
                ],
            ],
        ],

        'DELETE_WIDGET' => [
            'description'          => 'Delete a widget from the screen',
            'requires_new_id'      => false,
            'requires_confirmation'=> true,  // destructive
            'reversible'           => true,
            'required_payload'     => ['widget_id'],
            'optional_payload'     => [],
        ],

        'MOVE_WIDGET' => [
            'description'          => 'Move a widget up or down within its parent',
            'requires_new_id'      => false,
            'requires_confirmation'=> false,
            'reversible'           => true,
            'required_payload'     => ['widget_id', 'direction'],
            'optional_payload'     => [],
        ],

        'DUPLICATE_WIDGET' => [
            'description'          => 'Duplicate a widget (copy with new ID)',
            'requires_new_id'      => true,
            'requires_confirmation'=> false,
            'reversible'           => true,
            'required_payload'     => ['widget_id'],
            'optional_payload'     => [],
        ],

        // ── Property / Style ─────────────────────────────────────────
        'UPDATE_PROPERTY' => [
            'description'          => 'Update a single property of a widget',
            'requires_new_id'      => false,
            'requires_confirmation'=> false,
            'reversible'           => true,
            'required_payload'     => ['widget_id', 'property_name', 'property_value'],
            'optional_payload'     => [],
        ],

        'UPDATE_STYLE' => [
            'description'          => 'Update visual styling properties of a widget',
            'requires_new_id'      => false,
            'requires_confirmation'=> false,
            'reversible'           => true,
            'required_payload'     => ['widget_id', 'style_properties'],
            'optional_payload'     => [],
        ],

        // ── Screen management ────────────────────────────────────────
        'CREATE_SCREEN' => [
            'description'          => 'Create a new screen in the project',
            'requires_new_id'      => true,
            'requires_confirmation'=> false,
            'reversible'           => true,
            'required_payload'     => ['screen_name'],
            'optional_payload'     => ['template'],
        ],

        'DELETE_SCREEN' => [
            'description'          => 'Delete a screen from the project',
            'requires_new_id'      => false,
            'requires_confirmation'=> true,  // destructive
            'reversible'           => false,
            'required_payload'     => ['screen_id'],
            'optional_payload'     => [],
        ],

        'RENAME_SCREEN' => [
            'description'          => 'Rename a screen',
            'requires_new_id'      => false,
            'requires_confirmation'=> false,
            'reversible'           => true,
            'required_payload'     => ['screen_id', 'new_name'],
            'optional_payload'     => [],
        ],

        // ── Navigation ───────────────────────────────────────────────
        'ADD_NAVIGATION' => [
            'description'          => 'Add navigation action to a widget (sets onPressed to navigate to a screen). Uses existing widget property system.',
            'requires_new_id'      => false,
            'requires_confirmation'=> false,
            'reversible'           => true,
            'required_payload'     => ['source_widget_id', 'destination_screen_name'],
            'optional_payload'     => ['navigation_type'],
        ],

        'REMOVE_NAVIGATION' => [
            'description'          => 'Remove navigation action from a widget',
            'requires_new_id'      => false,
            'requires_confirmation'=> false,
            'reversible'           => true,
            'required_payload'     => ['widget_id'],
            'optional_payload'     => [],
        ],

        // ── Events / Interactions ────────────────────────────────────
        'ADD_EVENT' => [
            'description'          => 'Add an event handler to a widget',
            'requires_new_id'      => false,
            'requires_confirmation'=> false,
            'reversible'           => true,
            'required_payload'     => ['widget_id', 'event_name', 'event_action'],
            'optional_payload'     => [],
        ],

        'REMOVE_EVENT' => [
            'description'          => 'Remove an event handler from a widget',
            'requires_new_id'      => false,
            'requires_confirmation'=> false,
            'reversible'           => true,
            'required_payload'     => ['widget_id', 'event_name'],
            'optional_payload'     => [],
        ],

        // ── Theme ────────────────────────────────────────────────────
        'UPDATE_THEME' => [
            'description'          => 'Update global theme properties of the app',
            'requires_new_id'      => false,
            'requires_confirmation'=> false,
            'reversible'           => true,
            'required_payload'     => ['theme_properties'],
            'optional_payload'     => [],
        ],
    ];

    /**
     * Check if an action type is registered.
     */
    public static function isRegistered(string $actionType): bool
    {
        return isset(self::$actions[$actionType]);
    }

    /**
     * Get action definition.
     */
    public static function get(string $actionType): ?array
    {
        return self::$actions[$actionType] ?? null;
    }

    /**
     * Check if action requires user confirmation.
     */
    public static function requiresConfirmation(string $actionType): bool
    {
        return self::$actions[$actionType]['requires_confirmation'] ?? false;
    }

    /**
     * Check if action requires Flutter to generate a new widget ID.
     */
    public static function requiresNewId(string $actionType): bool
    {
        return self::$actions[$actionType]['requires_new_id'] ?? false;
    }

    /**
     * Get required payload fields for an action type.
     */
    public static function getRequiredPayload(string $actionType): array
    {
        return self::$actions[$actionType]['required_payload'] ?? [];
    }

    /**
     * Get compact list for LLM context.
     */
    public static function getCompactList(): array
    {
        $list = [];
        foreach (self::$actions as $type => $def) {
            $list[] = [
                'type'        => $type,
                'description' => $def['description'],
                'required'    => $def['required_payload'],
            ];
        }
        return $list;
    }
}
