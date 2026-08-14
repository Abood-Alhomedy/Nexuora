<?php

namespace App\AI\Providers;

use App\AI\Contracts\LLMProvider;
use App\AI\Exceptions\LLMUnavailableException;
use App\AI\Exceptions\RateLimitException;
use App\AI\Exceptions\InvalidLLMResponseException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * OpenRouterProvider — implements LLMProvider for OpenRouter.ai
 *
 * This is the ONLY class that knows about OpenRouter.
 * Business logic (Orchestrator, Analyzers, etc.) only knows LLMProvider.
 */
class OpenRouterProvider implements LLMProvider
{
    private string $apiKey;
    private string $model;
    private int    $maxTokens;
    private float  $temperature;
    private int    $timeout;
    private int    $maxRetries;
    private string $baseUrl;
    private string $referer;

    public function __construct()
    {
        $this->apiKey      = config('ai.api_key', '');
        $this->model       = config('ai.model', 'openrouter/free');
        $this->maxTokens   = config('ai.max_tokens', 2048);
        $this->temperature = config('ai.temperature', 0.2);
        $this->timeout     = config('ai.timeout', 30);
        $this->maxRetries  = config('ai.max_retries', 2);
        $this->baseUrl     = config('ai.providers.openrouter.base_url', 'https://openrouter.ai/api/v1');
        $this->referer     = config('ai.providers.openrouter.referer', config('app.url', 'http://localhost'));
    }

    /**
     * Send structured chat and return parsed PHP array conforming to $jsonSchema.
     */
    public function chat(array $messages, array $jsonSchema): array
    {
        $attempt = 0;
        $lastError = null;

        // Build system message enforcing JSON output
        $schemaInstructions = $this->buildSchemaInstructions($jsonSchema);
        $messagesWithSchema = $this->injectSchemaInstructions($messages, $schemaInstructions);

        while ($attempt <= $this->maxRetries) {
            try {
                $response = $this->sendRequest($messagesWithSchema);
                $parsed   = $this->parseResponse($response);
                $this->validateAgainstSchema($parsed, $jsonSchema);
                return $parsed;
            } catch (InvalidLLMResponseException $e) {
                $lastError = $e;
                $attempt++;
                if ($attempt <= $this->maxRetries) {
                    // Add correction instruction and retry
                    $messagesWithSchema[] = [
                        'role'    => 'assistant',
                        'content' => $response ?? 'invalid',
                    ];
                    $messagesWithSchema[] = [
                        'role'    => 'user',
                        'content' => 'Your previous response was not valid JSON conforming to the required schema. ' .
                                     'Please respond ONLY with a valid JSON object matching the schema. ' .
                                     'Error: ' . $e->getMessage(),
                    ];
                    Log::warning('[AI] LLM returned invalid JSON, retrying', ['attempt' => $attempt, 'error' => $e->getMessage()]);
                }
            }
        }

        throw new InvalidLLMResponseException(
            'LLM failed to return valid JSON after ' . ($this->maxRetries + 1) . ' attempts. Last error: ' . $lastError?->getMessage()
        );
    }

    /**
     * Health check — verifies API key and model availability.
     */
    public function isAvailable(): bool
    {
        if (empty($this->apiKey)) {
            return false;
        }
        try {
            $response = Http::withHeaders($this->buildHeaders())
                ->timeout(5)
                ->get($this->baseUrl . '/models');
            return $response->successful();
        } catch (\Throwable $e) {
            Log::warning('[AI] Health check failed', ['error' => $e->getMessage()]);
            return false;
        }
    }

    public function getProviderName(): string
    {
        return 'openrouter';
    }

    public function getModelName(): string
    {
        return $this->model;
    }

    // ─────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────

    private function sendRequest(array $messages): ?string
    {
        $payload = [
            'model'       => $this->model,
            'messages'    => $messages,
            'max_tokens'  => $this->maxTokens,
            'temperature' => $this->temperature,
        ];

        try {
            $response = Http::withHeaders($this->buildHeaders())
                ->timeout($this->timeout)
                ->post($this->baseUrl . '/chat/completions', $payload);

            if ($response->status() === 429) {
                throw new RateLimitException('OpenRouter rate limit reached. Please try again later.');
            }

            if (!$response->successful()) {
                $body = $response->json();
                $errorMsg = $body['error']['message'] ?? 'Unknown provider error';
                throw new LLMUnavailableException('OpenRouter error: ' . $errorMsg);
            }

            $content = $response->json('choices.0.message.content');
            if (empty($content)) {
                throw new InvalidLLMResponseException('OpenRouter returned empty content');
            }

            return $content;

        } catch (RateLimitException | LLMUnavailableException $e) {
            throw $e;
        } catch (\Throwable $e) {
            Log::error('[AI] OpenRouter request failed', ['error' => $e->getMessage()]);
            throw new LLMUnavailableException('Could not connect to AI service: ' . $e->getMessage());
        }
    }

    private function parseResponse(?string $raw): array
    {
        if (empty($raw)) {
            throw new InvalidLLMResponseException('Empty response from LLM');
        }

        // Extract JSON block if wrapped in markdown code fences
        $json = $this->extractJson($raw);

        $decoded = json_decode($json, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new InvalidLLMResponseException('Invalid JSON from LLM: ' . json_last_error_msg());
        }

        return $decoded;
    }

    private function extractJson(string $text): string
    {
        // Strip markdown code fences if present
        if (preg_match('/```(?:json)?\s*(\{.*?\})\s*```/s', $text, $matches)) {
            return $matches[1];
        }
        // Try to find raw JSON object
        if (preg_match('/\{.*\}/s', $text, $matches)) {
            return $matches[0];
        }
        return $text;
    }

    private function validateAgainstSchema(array $data, array $schema): void
    {
        // Basic required-fields check from JSON schema
        if (isset($schema['required']) && is_array($schema['required'])) {
            foreach ($schema['required'] as $field) {
                if (!array_key_exists($field, $data)) {
                    throw new InvalidLLMResponseException("Required field '{$field}' missing from LLM response");
                }
            }
        }
    }

    private function buildSchemaInstructions(array $jsonSchema): string
    {
        return "You MUST respond with ONLY a valid JSON object. No explanation, no markdown, no code fences.\n" .
               "The JSON must exactly match this schema:\n" .
               json_encode($jsonSchema, JSON_PRETTY_PRINT);
    }

    private function injectSchemaInstructions(array $messages, string $instructions): array
    {
        // Prepend to system message or insert one
        $systemIdx = null;
        foreach ($messages as $i => $m) {
            if ($m['role'] === 'system') {
                $systemIdx = $i;
                break;
            }
        }
        if ($systemIdx !== null) {
            $messages[$systemIdx]['content'] .= "\n\n" . $instructions;
        } else {
            array_unshift($messages, ['role' => 'system', 'content' => $instructions]);
        }
        return $messages;
    }

    /**
     * Sanitize user input to reduce prompt injection risk.
     * This is called by AIOrchestrator before passing user message to the provider.
     */
    public static function sanitizeUserInput(string $input): string
    {
        // Truncate to reasonable length
        $input = mb_substr($input, 0, 2000);

        // Strip patterns that look like instruction injection
        $injectionPatterns = [
            '/ignore (all )?(previous|above|prior) instructions?/i',
            '/you are now/i',
            '/act as/i',
            '/system prompt/i',
            '/\[INST\]/i',
            '/<\|im_start\|>/i',
            '/<<<.*?>>>/s',
        ];
        foreach ($injectionPatterns as $pattern) {
            $input = preg_replace($pattern, '[removed]', $input);
        }

        return trim($input);
    }

    private function buildHeaders(): array
    {
        return [
            'Authorization'  => 'Bearer ' . $this->apiKey,
            'Content-Type'   => 'application/json',
            'HTTP-Referer'   => $this->referer,
            'X-Title'        => 'Nexuora AI App Builder',
        ];
    }
}
