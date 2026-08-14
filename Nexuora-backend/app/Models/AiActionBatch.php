<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AiActionBatch extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'conversation_id', 'message_id', 'project_id', 'screen_id',
        'status', 'action_descriptors', 'action_results', 'execution_metadata',
    ];

    protected $casts = [
        'action_descriptors'  => 'array',
        'action_results'      => 'array',
        'execution_metadata'  => 'array',
        'created_at'          => 'datetime',
        'updated_at'          => 'datetime',
    ];

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(AiConversation::class, 'conversation_id');
    }
}
