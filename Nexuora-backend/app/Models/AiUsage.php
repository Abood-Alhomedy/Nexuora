<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AiUsage extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'user_id', 'project_id', 'conversation_id',
        'provider', 'model', 'input_tokens', 'output_tokens',
        'latency_ms', 'request_count', 'status', 'error_type',
    ];

    protected $casts = [
        'created_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
