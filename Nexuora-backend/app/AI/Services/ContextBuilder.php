<?php

namespace App\AI\Services;

use App\Project;
use App\Screen;

/**
 * ContextBuilder — Backend DB state only.
 *
 * Responsibility: Build a compact "project context" from the database
 * for the LLM to understand the current state of the project.
 *
 * Does NOT handle: selected widget, scroll position, or any UI state
 * (those come from the Flutter request payload).
 */
class ContextBuilder
{
    /**
     * Build project context for the given scope.
     *
     * @param  int    $projectId
     * @param  int    $userId
     * @param  int|null $currentScreenId  — current screen from Flutter UI
     * @param  array  $uiContext          — from Flutter: selected_widget_id, selected_widget_type, etc.
     * @param  string $scope              — 'widget_only' | 'screen' | 'full_project'
     * @return array
     */
    public function build(
        int $projectId,
        int $userId,
        ?int $currentScreenId = null,
        array $uiContext = [],
        string $scope = 'screen'
    ): array {
        $project = Project::where('id', $projectId)->where('user_id', $userId)->first();
        if (!$project) {
            return ['error' => 'project_not_found'];
        }

        $context = [
            'project' => [
                'id'   => $project->id,
                'name' => $project->project_name ?? $project->name ?? 'Unnamed Project',
            ],
            'ui_context' => $uiContext, // passed through from Flutter
        ];

        if ($scope === 'full_project') {
            // All screens (summary only — no full widget trees)
            $screens = Screen::where('project_id', $projectId)->get(['id', 'screen_name']);
            $context['all_screens'] = $screens->map(fn($s) => [
                'id'   => $s->id,
                'name' => $s->screen_name,
            ])->toArray();
        }

        if ($currentScreenId) {
            $screen = Screen::where('id', $currentScreenId)->where('project_id', $projectId)->first();
            if ($screen) {
                $context['current_screen'] = [
                    'id'   => $screen->id,
                    'name' => $screen->screen_name,
                ];

                // Parse screen data (ScreenJsonData JSON)
                $screenData = $screen->data;
                if (is_string($screenData)) {
                    $screenData = json_decode($screenData, true);
                }

                if ($scope === 'screen' || $scope === 'full_project') {
                    // Include the full widget tree so TargetResolver can search it
                    $context['widget_tree'] = $screenData;

                    // Also provide a flat list of widget IDs+types for easier LLM reading
                    $context['widget_index'] = $this->buildWidgetIndex($screenData);
                    \Log::debug('[AI DEBUG] Generated Widget Index', [
                        'widget_index' => $context['widget_index'],
                    ]);
                } elseif ($scope === 'widget_only' && !empty($uiContext['selected_widget_id'])) {
                    // Provide only the selected widget and its immediate parent
                    $context['widget_index'] = $this->buildWidgetIndex($screenData);
                }
            }
        }

        return $context;
    }

    /**
     * Build a flat index of all widgets in the tree: [{id, type, text_label}]
     * Used by TargetResolver for semantic matching.
     */
/**
 * Build a flat index of all widgets in the screen.
 *
 * The Flutter Viz data structure uses:
 *
 * type    = NormalView
 * subType = Text
 *
 * Therefore we use subType as the semantic widget type.
 */
private function buildWidgetIndex(?array $widgetTree): array
{
    $index = [];

    if (empty($widgetTree) || !is_array($widgetTree)) {
        return $index;
    }

    $walk = function ($node) use (&$walk, &$index) {

        if (!is_array($node)) {
            return;
        }

        /*
         * Widget ID
         */
        $widgetId = $node['widgetId'] ?? null;

        /*
         * Semantic widget type.
         *
         * Example:
         *
         * type    = NormalView
         * subType = Text
         *
         * We want:
         *
         * type = Text
         */
        $type = $node['subType']
            ?? $node['type']
            ?? null;

        if ($widgetId && $type) {

            $label = '';

            /*
             * Text widget
             *
             * Your actual data structure is:
             *
             * "Text": {
             *     "text": "Text",
             *     ...
             * }
             */
            if ($type === 'Text') {

                $label = $node['Text']['text'] ?? '';
            }

            /*
             * Button
             */
            elseif ($type === 'Button') {

                $label =
                    $node['Button']['text']
                    ?? $node['Button']['label']
                    ?? '';
            }

            /*
             * TextField
             */
            elseif ($type === 'TextField') {

                $label =
                    $node['TextField']['hintText']
                    ?? $node['TextField']['label']
                    ?? '';
            }

            /*
             * Image
             */
            elseif ($type === 'Image') {

                $label =
                    $node['Image']['imageUrl']
                    ?? $node['Image']['url']
                    ?? '';
            }

            /*
             * Generic fallback
             */
            if ($label === '') {

                $label =
                    $node['label']
                    ?? $node['name']
                    ?? '';
            }

            $index[] = [
                'id'    => (string) $widgetId,
                'type'  => (string) $type,
                'label' => (string) $label,
            ];
        }

        /*
         * Recursively scan child widgets.
         */
        if (!empty($node['childData']) && is_array($node['childData'])) {

            foreach ($node['childData'] as $child) {
                $walk($child);
            }
        }
    };

    /*
     * Main widget tree.
     *
     * Example:
     *
     * widgetsData
     *     ↓
     * RowLayout
     *     ↓
     * childData
     *     ↓
     * Text
     */
    if (!empty($widgetTree['widgetsData'])) {

        $walk($widgetTree['widgetsData']);
    }

    /*
     * Other possible widget containers.
     */
    foreach ([
        'appBarData',
        'bottomBarNavigationData',
        'drawerData',
    ] as $key) {

        if (
            !empty($widgetTree[$key]) &&
            is_array($widgetTree[$key])
        ) {

            $walk($widgetTree[$key]);
        }
    }

    return $index;
}
}
