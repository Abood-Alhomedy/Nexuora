<?php

namespace App\AI\LLM;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class OpenRouterClient
{
    protected string $apiKey;
    protected string $model;
    protected string $baseUrl;

    public function __construct()
    {
        $this->apiKey = config('ai.openrouter.api_key');
        $this->model = config('ai.openrouter.model');
        $this->baseUrl = config('ai.openrouter.base_url');
    }

    public function chatCompletion(
        string $systemPrompt,
        string $userMessage,
        float $temperature = 0.3,
        ?array $messagesHistory = null
    ): array {

        $messages = $messagesHistory ?? [
            [
                'role' => 'system',
                'content' => $systemPrompt,
            ],
            [
                'role' => 'user',
                'content' => $userMessage,
            ],
        ];

      $response = Http::withToken($this->apiKey)
    ->acceptJson()
    ->post($this->baseUrl . '/chat/completions', [
        'model' => $this->model,
        'messages' => $messages,
        'temperature' => $temperature,
        'response_format' => [
            'type' => 'json_object',
        ],
    ]);
        if (!$response->successful()) {
            throw new RuntimeException(
                'OpenRouter request failed: ' . $response->body()
            );
        }

        $data = $response->json();

        if (
            !isset($data['choices'][0]['message'])
        ) {
            throw new RuntimeException(
                'Invalid response from OpenRouter.'
            );
        }

        return $data['choices'][0]['message'];
    }

    public function chatCompletionJson(
        string $systemPrompt,
        string $userMessage,
        float $temperature = 0.2
    ): array {

        $message = $this->chatCompletion(
            $systemPrompt,
            $userMessage,
            $temperature
        );

        $content = $message['content'] ?? '';

        if (!$content) {
            throw new RuntimeException(
                'LLM returned an empty response.'
            );
        }

        $content = trim($content);

        // Remove Markdown code fences.
        if (str_starts_with($content, '```')) {

            $lines = preg_split(
                '/\r\n|\r|\n/',
                $content
            );

            if (
                isset($lines[0]) &&
                str_starts_with(trim($lines[0]), '```')
            ) {
                array_shift($lines);
            }

            if (
                !empty($lines) &&
                trim(end($lines)) === '```'
            ) {
                array_pop($lines);
            }

            $content = trim(implode("\n", $lines));
        }

        $data = json_decode(
            $content,
            true
        );

        if (
            json_last_error() !== JSON_ERROR_NONE
        ) {
            throw new RuntimeException(
                'LLM returned invalid JSON: ' .
                json_last_error_msg()
            );
        }

        if (!is_array($data)) {
            throw new RuntimeException(
                'LLM response must be a JSON object.'
            );
        }

        return $data;
    }
}