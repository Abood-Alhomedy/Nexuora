<?php

namespace App\AI\Services;

use App\Models\AiConversation;
use App\Models\AiMessage;

/**
 * ConversationManager — manages multi-turn conversation state.
 *
 * Handles:
 * - Creating/loading ai_conversations records
 * - Appending ai_messages
 * - Intent continuity detection (same vs new intent)
 * - State: current_intent, collected_parameters, missing_parameters
 */
class ConversationManager
{
    /**
     * Load or create a conversation for this project.
     */
    public function loadOrCreate(int $userId, int $projectId, ?int $conversationId): AiConversation
    {
        if ($conversationId) {
            $conversation = AiConversation::where('id', $conversationId)
                ->where('user_id', $userId)
                ->where('project_id', $projectId)
                ->first();
            if ($conversation) return $conversation;
        }

        return AiConversation::create([
            'user_id'    => $userId,
            'project_id' => $projectId,
            'title'      => 'AI Session - ' . now()->format('M d, H:i'),
            'metadata'   => [],
        ]);
    }

    /**
     * Append a message to the conversation.
     */
    public function appendMessage(
        int    $conversationId,
        string $role,
        string $content,
        ?string $intent = null,
        ?string $confidence = null,
        array   $metadata = []
    ): AiMessage {
        return AiMessage::create([
            'conversation_id' => $conversationId,
            'role'            => $role,
            'content'         => $content,
            'intent'          => $intent,
            'confidence'      => $confidence,
            'metadata'        => $metadata,
        ]);
    }

    /**
     * Get recent messages for context (last N).
     */
    public function getHistory(int $conversationId, int $limit = 10): array
    {
        return AiMessage::where('conversation_id', $conversationId)
            ->orderBy('created_at', 'desc')
            ->limit($limit)
            ->get()
            ->reverse()
            ->map(fn($m) => [
                'role'    => $m->role,
                'content' => $m->content,
                'intent'  => $m->intent,
            ])
            ->values()
            ->toArray();
    }

    /**
     * Update conversation metadata (current_intent, collected params, etc.).
     */
    public function updateState(int $conversationId, array $state): void
    {
        $conversation = AiConversation::find($conversationId);
        if (!$conversation) return;

        $existing = $conversation->metadata ?? [];
        $conversation->metadata = array_merge($existing, $state);
        $conversation->save();
    }

    /**
     * Detect if the new intent continues the previous one or starts fresh.
     * Returns: 'continuation' | 'new'
     */
    public function detectIntentMode(AiConversation $conversation, string $newIntent): string
    {
        $currentIntent = $conversation->current_intent ?? ($conversation->metadata['current_intent'] ?? null);

        if (!$currentIntent) return 'new';
        if ($currentIntent === $newIntent) return 'continuation';

        // These intents commonly chain together
        $chainable = [
            'ADD_WIDGET'   => ['UPDATE_WIDGET', 'UPDATE_STYLE', 'ADD_EVENT', 'ADD_NAVIGATION'],
            'CREATE_SCREEN' => ['ADD_WIDGET', 'RENAME_SCREEN', 'ADD_NAVIGATION'],
        ];

        if (isset($chainable[$currentIntent]) && in_array($newIntent, $chainable[$currentIntent])) {
            return 'continuation';
        }

        return 'new';
    }

    /**
     * Mark a conversation with the active intent.
     */
    public function setCurrentIntent(AiConversation $conversation, string $intent): void
    {
        $conversation->current_intent = $intent;
        $meta = $conversation->metadata ?? [];
        $meta['current_intent'] = $intent;
        $conversation->metadata = $meta;
        $conversation->save();
    }
}
