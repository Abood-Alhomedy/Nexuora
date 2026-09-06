<?php

return [
    /*
    |--------------------------------------------------------------------------
    | AI Feature Toggle
    |--------------------------------------------------------------------------
    */
    'enabled' => env('AI_ENABLED', true),


    'openrouter' => [
        'api_key' => env('OPENROUTER_API_KEY'),
        'model' => env('OPENROUTER_MODEL'),
        'base_url' => 'https://openrouter.ai/api/v1',
    ],

    'generation' => [
        'temperature' => 0.2,
        'max_attempts' => 3,
    ],

    /*
    |--------------------------------------------------------------------------
    | LLM Provider
    | Supported: "openrouter", "openai", "anthropic", "gemini", "ollama"
    | Only "openrouter" is implemented in Phase 1.
    |--------------------------------------------------------------------------
    */
    'provider' => env('AI_PROVIDER', 'openrouter'),

    /*
    |--------------------------------------------------------------------------
    | Model name — always read from .env, never hard-coded in business logic
    |--------------------------------------------------------------------------
    */
    'model' => env('AI_MODEL', 'openrouter/free'),

    /*
    |--------------------------------------------------------------------------
    | API Access — kept server-side only, never exposed to Flutter
    |--------------------------------------------------------------------------
    */
    'api_key' => env('AI_API_KEY'),

    /*
    |--------------------------------------------------------------------------
    | Generation Parameters
    |--------------------------------------------------------------------------
    */
    'max_tokens'  => (int) env('AI_MAX_TOKENS', 2048),
    'temperature' => (float) env('AI_TEMPERATURE', 0.2),
    'timeout'     => (int) env('AI_TIMEOUT', 30),
    'max_retries' => (int) env('AI_MAX_RETRIES', 2),

    /*
    |--------------------------------------------------------------------------
    | Rate Limiting
    |--------------------------------------------------------------------------
    */
    'rate_limit' => [
        'rpm'            => (int) env('AI_RPM', 10),  // requests per minute per user
        'rpd'            => (int) env('AI_RPD', 100), // requests per day per user
        'max_actions'    => (int) env('AI_MAX_ACTIONS', 20), // max actions per request
        'max_ctx_tokens' => (int) env('AI_MAX_CTX_TOKENS', 4000), // approximate context limit
    ],

    /*
    |--------------------------------------------------------------------------
    | Provider Base URLs (not exposed to Flutter)
    |--------------------------------------------------------------------------
    */
    'providers' => [
        'openrouter' => [
            'base_url' => 'https://openrouter.ai/api/v1',
            'referer'  => env('APP_URL', 'http://localhost'),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Conversation Context Settings
    |--------------------------------------------------------------------------
    */
    'context' => [
        'recent_messages' => (int) env('AI_CONTEXT_RECENT_MESSAGES', 15),
        'max_memories'    => (int) env('AI_CONTEXT_MAX_MEMORIES', 10),
    ],
];
