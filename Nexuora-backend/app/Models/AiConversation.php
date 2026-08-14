<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AiConversation extends Model
{
    protected $fillable = [
        'user_id', 'project_id', 'title', 'current_intent', 'metadata',
    ];

    protected $casts = [
        'metadata' => 'array',
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
}
