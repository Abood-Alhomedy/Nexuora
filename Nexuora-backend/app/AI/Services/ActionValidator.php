<?php

namespace App\AI\Services;

use App\AI\Registry\ActionRegistry;
use App\AI\Registry\WidgetRegistry;
use App\AI\Exceptions\AIValidationException;
use App\AI\Exceptions\AIAuthorizationException;
use App\Project;
use App\Screen;

/**
 * ActionValidator — 10-check validation pipeline.
 *
 * Checks (in order, fail-fast):
 *  1.  Action type in ActionRegistry
 *  2.  Required payload fields present
 *  3.  Widget type in WidgetRegistry (if applicable)
 *  4.  Target widget exists in current screen
 *  5.  Parent widget accepts child type
 *  6.  Property is allowed for widget type
 *  7.  Property value type is valid
 *  8.  Cannot touch root Scaffold (semantic safety)
 *  9.  User owns the project (authorization)
 *  10. Action count within limit
 */
class ActionValidator
{
    /**
     * Validate all action descriptors in a batch.
     *
     * @throws AIValidationException
     * @throws AIAuthorizationException
     */
    public function validateAll(array $actionDescriptors, array $context, int $userId): void
    {
        // Check 9: Authorization — user owns project
        $projectId = $context['project']['id'] ?? null;
        if (!$projectId || !Project::where('id', $projectId)->where('user_id', $userId)->exists()) {
            throw new AIAuthorizationException('You do not have permission to modify this project.');
        }

        // Check 10: Action count
        $maxActions = config('ai.rate_limit.max_actions', 20);
        if (count($actionDescriptors) > $maxActions) {
            throw new AIValidationException(
                ["Too many actions in one request ({count($actionDescriptors)} > {$maxActions})"]
            );
        }

        $widgetIndex = $context['widget_index'] ?? [];

        foreach ($actionDescriptors as $i => $descriptor) {
            $this->validateOne($descriptor, $widgetIndex, $i);
        }
    }

    /**
     * Validate a single action descriptor.
     *
     * @throws AIValidationException
     */
    private function validateOne(array $descriptor, array $widgetIndex, int $index): void
    {
        $errors = [];
        $pos    = "Action[{$index}]";
        $type   = $descriptor['type'] ?? '';
        $target = $descriptor['target'] ?? [];
        $payload = $descriptor['payload'] ?? [];

        // Check 1: Action type registered
        if (!ActionRegistry::isRegistered($type)) {
            throw new AIValidationException(["{$pos}: Unknown action type '{$type}'"]);
        }

        // Check 2: Required payload fields
        foreach (ActionRegistry::getRequiredPayload($type) as $field) {
            if (!isset($payload[$field]) && !isset($target[$field])) {
                $errors[] = "{$pos}: Missing required field '{$field}'";
            }
        }

        $widgetType = $payload['widget_type'] ?? null;

        // Check 3: Widget type in registry (for widget actions)
        if ($widgetType && !WidgetRegistry::isSupported($widgetType)) {
            $errors[] = "{$pos}: Unsupported widget type '{$widgetType}'";
        }

        // Check 4: Target widget exists (for operations on existing widgets)
        if (in_array($type, ['UPDATE_WIDGET', 'DELETE_WIDGET', 'MOVE_WIDGET',
                              'DUPLICATE_WIDGET', 'UPDATE_PROPERTY', 'UPDATE_STYLE',
                              'ADD_NAVIGATION', 'REMOVE_NAVIGATION', 'ADD_EVENT', 'REMOVE_EVENT'])) {
            $widgetId = $target['widget_id'] ?? null;
            if ($widgetId) {
                $found = collect($widgetIndex)->firstWhere('id', $widgetId);
                if (!$found) {
                    $errors[] = "{$pos}: Widget ID '{$widgetId}' not found in current screen";
                } else {
                    // Check 8: Cannot modify root Scaffold directly
                    if ($found['type'] === 'Scaffold' && $type === 'DELETE_WIDGET') {
                        $errors[] = "{$pos}: Cannot delete the root Scaffold widget";
                    }
                }
            }
        }

        // Check 5: Parent accepts child (for ADD_WIDGET)
        if ($type === 'ADD_WIDGET' && $widgetType) {
            $parentId = $target['parent_id'] ?? null;
            if ($parentId) {
                $parent = collect($widgetIndex)->firstWhere('id', $parentId);
                if ($parent) {
                    if (!WidgetRegistry::canAcceptChild($parent['type'], $widgetType)) {
                        $errors[] = "{$pos}: Widget type '{$parent['type']}' does not accept '{$widgetType}' as a child";
                    }
                }
            }
        }

        // Check 6 + 7: Properties allowed and value types valid
        if (in_array($type, ['UPDATE_WIDGET', 'UPDATE_PROPERTY', 'UPDATE_STYLE'])) {
            $widgetId   = $target['widget_id'] ?? null;
            $targetWidget = $widgetId ? collect($widgetIndex)->firstWhere('id', $widgetId) : null;
            $targetType   = $targetWidget['type'] ?? null;

            $properties = $payload['properties'] ?? $payload['style_properties'] ?? [];
            foreach ($properties as $propName => $propValue) {
                if ($targetType && !WidgetRegistry::isPropertyAllowed($targetType, $propName)) {
                    $errors[] = "{$pos}: Property '{$propName}' is not allowed for widget type '{$targetType}'";
                }
                $typeError = $this->validatePropertyValue($propName, $propValue);
                if ($typeError) {
                    $errors[] = "{$pos}: {$typeError}";
                }
            }
        }

        if (!empty($errors)) {
            throw new AIValidationException($errors);
        }
    }

    /**
     * Validate property value types.
     */
    private function validatePropertyValue(string $name, mixed $value): ?string
    {
        // Color properties must be valid hex
        $colorProps = ['color', 'backgroundColor', 'foregroundColor', 'borderColor',
                       'fillColor', 'activeColor', 'inactiveColor', 'shadowColor',
                       'cardBgColor', 'selectedColor', 'todayColor', 'tileColor'];
        if (in_array($name, $colorProps)) {
            if (is_string($value) && !preg_match('/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$/', $value)) {
                return "Property '{$name}' must be a valid hex color (e.g., #FF5733)";
            }
        }

        // Numeric properties
        $numericProps = ['fontSize', 'width', 'height', 'elevation', 'borderRadius',
                         'opacity', 'size', 'thickness', 'letterSpacing', 'wordSpacing', 'height'];
        if (in_array($name, $numericProps) && !is_numeric($value)) {
            return "Property '{$name}' must be a number";
        }

        // Boolean properties
        $boolProps = ['isExpanded', 'shrinkWrap', 'autoPlay', 'looping', 'animate',
                      'repeat', 'obscureText', 'isFilled', 'dense', 'isScrollable', 'centerTitle'];
        if (in_array($name, $boolProps) && !is_bool($value)) {
            return "Property '{$name}' must be a boolean";
        }

        return null;
    }
}
