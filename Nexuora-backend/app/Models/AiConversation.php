<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AiConversation extends Model
{
    protected $fillable = [
        'user_id', 'project_id', 'title', 'current_intent', 'metadata',
        'summary', 'last_message_at',
    ];

    protected $casts = [
        'metadata'        => 'array',
        'last_message_at' => 'datetime',
    ];

    public function messages(): HasMany
    {
        return $this->hasMany(AiMessage::class, 'conversation_id');
    }

    public function actionBatches(): HasMany
    {
        return $this->hasMany(AiActionBatch::class, 'conversation_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function project(): BelongsTo
    {
        return $this->belongsTo(\App\Models\Project::class);
    }
}
