<?php

namespace App\AI\Services;

/**
 * TargetResolver — resolves widget targets by 7-level priority.
 *
 * Priority Order:
 *  1. Explicit ID in request (from selected_widget_id in Flutter UI)
 *  2. Selected Widget from UI context (if user said "this" / "selected")
 *  3. Current Screen context (only widget of type X in screen)
 *  4. Semantic description matched against widget index
 *  5. Widget type/property matching
 *  6. Parent/Child relationship
 *  7. Clarification required
 *
 * The LLM never assigns a widget ID. IDs only come from WidgetIndex.
 */
class TargetResolver
{
    /**
     * Resolve target widget from intent result and context.
     *
     * @param  array  $intentResult  from IntentAnalyzer
     * @param  array  $context       from ContextBuilder (includes widget_index)
     * @return array  { matched: int, widget_id: string|null, candidates: array, reason: string }
     */
    public function resolve(array $intentResult, array $context): array
    {
        $target      = $intentResult['target'] ?? [];
        $widgetIndex = $context['widget_index'] ?? [];
        $uiContext   = $context['ui_context'] ?? [];

        $intentName = $intentResult['intent'] ?? '';

        // ── تخصيص تام لـ ADD_WIDGET ─────────────────────────────────────
        if ($intentName === 'ADD_WIDGET') {
            $explicitParentId = $target['parent_id'] ?? null;
            $currentParentId  = $uiContext['current_parent_widget_id'] ?? null;
            $selectedWidgetId = $uiContext['selected_widget_id'] ?? null;

            // 1. Explicit parent_id
            if ($explicitParentId) {
                $found = $this->findById($explicitParentId, $widgetIndex);
                if ($found && $this->isValidWidgetParent($found)) {
                    return $this->found($found['id'], 'explicit_parent', ['is_parent_target' => true, 'parent_type' => $found['type']]);
                }
            }

            // 2. Parent supplied by Flutter
            if ($currentParentId) {
                $found = $this->findById($currentParentId, $widgetIndex);
                if ($found && $this->isValidWidgetParent($found)) {
                    return $this->found($found['id'], 'current_parent_context', ['is_parent_target' => true, 'parent_type' => $found['type']]);
                }
            }

            // 3. Selected widget ONLY if it is actually a container
            if ($selectedWidgetId) {
                $found = $this->findById($selectedWidgetId, $widgetIndex);
                if ($found && $this->isValidWidgetParent($found)) {
                    return $this->found($found['id'], 'selected_container', ['is_parent_target' => true, 'parent_type' => $found['type']]);
                }
            }

            // 4. Use the root widget
            $rootWidget = $this->findWidgetTreeRoot($context);
            if ($rootWidget && $this->isValidWidgetParent($rootWidget)) {
                return $this->found($rootWidget['id'], 'screen_root', ['is_parent_target' => true, 'parent_type' => $rootWidget['type']]);
            }

            // 5. Empty screen fallback
            return $this->found('', 'empty_screen', ['is_parent_target' => true, 'parent_type' => 'screen_root']);
        }


        // ── لبقية النوايا (Update, Delete...) استمر في الأولويات الـ 5 ──
        $selectedId = $uiContext['selected_widget_id'] ?? null;
        $isModification = in_array($intentName, ['UPDATE_WIDGET', 'UPDATE_PROPERTY', 'UPDATE_STYLE', 'DELETE_WIDGET', 'MOVE_WIDGET']);
        $hasExplicitDescription = !empty($target['description']) || !empty($intentResult['parameters']['widget_type']);
        $isReferringToSelected = $this->isReferringToSelected($intentResult);

        // ── Priority 1: Selected widget ────
        if ($selectedId) {
            if ($isReferringToSelected || ($isModification && !$hasExplicitDescription)) {
                $found = $this->findById($selectedId, $widgetIndex);
                if ($found) return $this->found($found['id'], 'selected_widget');
            }
        }

        // ── Priority 2: Explicit widget_id ──────────────────
        if (!empty($target['widget_id'])) {
            $found = $this->findById($target['widget_id'], $widgetIndex);
            if ($found) return $this->found($found['id'], 'explicit_id');
        }

        // ── Priority 3: Only widget of described type ──────────────
        $targetType = $intentResult['parameters']['widget_type'] ?? $target['description'] ?? null;
        if ($targetType) {
            $byType = $this->findByType($targetType, $widgetIndex);
            if (count($byType) === 1) return $this->found($byType[0]['id'], 'unique_type_match');
        }

        // ── Priority 4: Semantic description matching ─────────────────
        $description = $target['description'] ?? '';
        if ($description) {
            $semantic = $this->semanticMatch($description, $widgetIndex);
            if (count($semantic) === 1) return $this->found($semantic[0]['id'], 'semantic_match');
            if (count($semantic) > 1)   return $this->ambiguous($semantic, 'multiple_semantic_matches');
        }

        // ── Priority 5: Type + property matching ─────────────────────
        if ($targetType && $description) {
            $byTypeDesc = $this->findByTypeAndLabel($targetType, $description, $widgetIndex);
            if (count($byTypeDesc) === 1) return $this->found($byTypeDesc[0]['id'], 'type_property_match');
            if (count($byTypeDesc) > 1)   return $this->ambiguous($byTypeDesc, 'type_property_ambiguous');
        }

        return $this->needsClarification('Please select the widget you want to modify, or describe it more specifically.');
    }
    
    /**
     * Resolve a screen target.
     */
    public function resolveScreen(array $intentResult, array $context): array
    {
        $allScreens   = $context['all_screens'] ?? [];
        $screenId     = $intentResult['parameters']['screen_id'] ?? null;
        $screenName   = $intentResult['parameters']['screen_name']
                     ?? $intentResult['parameters']['destination_screen_name']
                     ?? null;

        if ($screenId) {
            $found = collect($allScreens)->firstWhere('id', $screenId);
            if ($found) return $this->found($screenId, 'explicit_screen_id');
        }

        if ($screenName) {
            $matches = collect($allScreens)->filter(
                fn($s) => stripos($s['name'], $screenName) !== false
            )->values()->toArray();

            if (count($matches) === 1) return $this->found($matches[0]['id'], 'screen_name_match');
            if (count($matches) > 1)  return $this->ambiguous($matches, 'multiple_screens');
        }

        return $this->needsClarification('Please specify which screen you mean.');
    }

    // ─────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────


    /**
 * Determine whether a widget can act as a parent for ADD_WIDGET.
 *
 * Scaffold is intentionally excluded.
 */
private function isValidWidgetParent(array $widget): bool
{
    $type = strtolower(trim($widget['type'] ?? ''));

    $allowedParents = [
        'row',
        'column',
        'container',
        'card',
        'listview',
        'gridview',
        'stack',
        'pageview',
        'rotatedbox',
        'expanded',
        'flexible',
    ];

    return in_array($type, $allowedParents, true);
}


/**
 * Get the actual root widget from widgetsData.
 *
 * The root widget lives in:
 *
 * $context['widget_tree']['widgetsData']
 *
 * It must NOT use scaffoldData as the widget parent.
 */
private function findWidgetTreeRoot(array $context): ?array
{
    $root = $context['widget_tree']['widgetsData'] ?? null;

    if (!is_array($root)) {
        return null;
    }

    $id = $root['widgetId'] ?? null;

    $type = $root['subType']
        ?? $root['type']
        ?? null;

    if (!$id || !$type) {
        return null;
    }

    return [
        'id' => (string) $id,
        'type' => (string) $type,
        'label' => '',
    ];
}


    private function findById(string $id, array $index): ?array
    {
        foreach ($index as $widget) {
            if ($widget['id'] === $id) return $widget;
        }
        return null;
    }

    private function findByType(string $type, array $index): array
    {
        return array_values(array_filter($index, fn($w) => strcasecmp($w['type'], $type) === 0));
    }

    private function semanticMatch(string $description, array $index): array
    {
        $desc  = strtolower($description);
        $words = explode(' ', $desc);
        $hits  = [];

        foreach ($index as $widget) {
            $label = strtolower($widget['label'] ?? '');
            $type  = strtolower($widget['type'] ?? '');
            $score = 0;

            foreach ($words as $word) {
                if (strlen($word) < 3) continue;
                if (str_contains($label, $word) || str_contains($type, $word)) {
                    $score++;
                }
            }

            if ($score > 0) {
                $hits[] = ['widget' => $widget, 'score' => $score];
            }
        }

        usort($hits, fn($a, $b) => $b['score'] <=> $a['score']);

        // Return top matches only if their scores are equal — otherwise top 1
        if (empty($hits)) return [];
        $topScore = $hits[0]['score'];
        $top = array_filter($hits, fn($h) => $h['score'] === $topScore);
        return array_map(fn($h) => $h['widget'], array_values($top));
    }

    private function findByTypeAndLabel(string $type, string $description, array $index): array
    {
        $byType    = $this->findByType($type, $index);
        $semantic  = $this->semanticMatch($description, $byType);
        return $semantic ?: $byType;
    }

    private function isReferringToSelected(array $intentResult): bool
    {
        $desc = strtolower($intentResult['target']['description'] ?? '');
        $params = json_encode($intentResult['parameters'] ?? []);
        return str_contains($desc, 'selected')
            || str_contains($desc, 'this')
            || str_contains($desc, 'current')
            || str_contains(strtolower($params), 'selected');
    }

    private function found(string $id, string $reason, array $extra = []): array
    {
        return array_merge(['matched' => 1, 'widget_id' => $id, 'reason' => $reason, 'candidates' => []], $extra);
    }

    private function ambiguous(array $candidates, string $reason): array
    {
        return [
            'matched'    => count($candidates),
            'widget_id'  => null,
            'reason'     => $reason,
            'candidates' => array_map(fn($c) => [
                'id'    => $c['id'],
                'type'  => $c['type'],
                'label' => $c['label'],
            ], $candidates),
        ];
    }

    private function notFound(string $reason): array
    {
        return ['matched' => 0, 'widget_id' => null, 'reason' => $reason, 'candidates' => []];
    }

    private function needsClarification(string $question): array
    {
        return ['matched' => -1, 'widget_id' => null, 'reason' => 'clarification_required',
                'clarification_question' => $question, 'candidates' => []];
    }
}
