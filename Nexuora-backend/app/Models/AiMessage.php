<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AiMessage extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'conversation_id', 'role', 'content', 'intent', 'confidence', 'metadata',
    ];

    protected $casts = [
        'metadata'   => 'array',
        'created_at' => 'datetime',
    ];

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(AiConversation::class, 'conversation_id');
    }
}
