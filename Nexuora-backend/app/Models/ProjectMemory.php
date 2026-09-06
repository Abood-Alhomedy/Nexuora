<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Builder;

/**
 * ProjectMemory — stores persistent AI-extracted facts about a project.
 *
 * Schema columns:
 *   id, project_id, key, value, type, importance,
 *   source_conversation_id, created_at, updated_at
 *
 * Unique constraint: (project_id, key) — one value per key per project.
 *
 * Types: preference | project_fact | design_rule | ui_fact | technical_constraint
 * Importance: low | medium | high
 */
class ProjectMemory extends Model
{
    protected $fillable = [
        'project_id',
        'key',
        'value',
        'type',
        'importance',
        'source_conversation_id',
    ];

    // ─────────────────────────────────────────────────────────
    // Relations
    // ─────────────────────────────────────────────────────────

    public function project(): BelongsTo
    {
        return $this->belongsTo(Project::class);
    }

    public function sourceConversation(): BelongsTo
    {
        return $this->belongsTo(AiConversation::class, 'source_conversation_id');
    }

    // ─────────────────────────────────────────────────────────
    // Scopes
    // ─────────────────────────────────────────────────────────

    /**
     * Filter memories for a specific project.
     */
    public function scopeForProject(Builder $query, int $projectId): Builder
    {
        return $query->where('project_id', $projectId);
    }

    /**
     * Order by importance (high → medium → low).
     */
    public function scopeByImportance(Builder $query): Builder
    {
        return $query->orderByRaw("FIELD(importance, 'high', 'medium', 'low')");
    }

    /**
     * Filter to high and medium importance only.
     */
    public function scopeRelevant(Builder $query): Builder
    {
        return $query->whereIn('importance', ['high', 'medium']);
    }

    // ─────────────────────────────────────────────────────────
    // Static helpers
    // ─────────────────────────────────────────────────────────

    /**
     * Upsert a memory by (project_id, key).
     *
     * If the key exists → update value/type/importance/source.
     * If it doesn't exist → create it.
     *
     * This prevents contradictory memories (same key, different values).
     */
    public static function upsertMemory(
        int     $projectId,
        string  $key,
        string  $value,
        string  $type,
        string  $importance,
        ?int    $sourceConversationId = null
    ): static {
        $memory = static::where('project_id', $projectId)
            ->where('key', $key)
            ->first();

        if ($memory) {
            $memory->update([
                'value'                  => $value,
                'type'                   => $type,
                'importance'             => $importance,
                'source_conversation_id' => $sourceConversationId ?? $memory->source_conversation_id,
            ]);
        } else {
            $memory = static::create([
                'project_id'             => $projectId,
                'key'                    => $key,
                'value'                  => $value,
                'type'                   => $type,
                'importance'             => $importance,
                'source_conversation_id' => $sourceConversationId,
            ]);
        }

        return $memory;
    }

    // ─────────────────────────────────────────────────────────
    // Validation helpers
    // ─────────────────────────────────────────────────────────

    public static function allowedTypes(): array
    {
        return ['preference', 'project_fact', 'design_rule', 'ui_fact', 'technical_constraint'];
    }

    public static function allowedImportance(): array
    {
        return ['low', 'medium', 'high'];
    }
}
