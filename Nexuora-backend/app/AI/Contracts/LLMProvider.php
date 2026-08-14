<?php

namespace App\AI\Contracts;

/**
 * LLMProvider — the only abstraction between business logic and any AI provider.
 *
 * OpenRouter, OpenAI, Anthropic, Gemini, Ollama etc. all implement this.
 * Nothing outside app/AI/Providers/ should know which concrete implementation is used.
 */
interface LLMProvider
{
    /**
     * Send a structured chat request and return parsed PHP array.
     *
     * @param  array  $messages    [['role'=>'system','content'=>'...'], ['role'=>'user','content'=>'...']]
     * @param  array  $jsonSchema  JSON Schema that the response MUST conform to (enforced via prompt + parsing)
     * @return array               Parsed and validated response matching $jsonSchema
     *
     * @throws \App\AI\Exceptions\LLMUnavailableException   provider is down / key invalid
     * @throws \App\AI\Exceptions\RateLimitException        provider rate limit hit
     * @throws \App\AI\Exceptions\InvalidLLMResponseException  could not parse valid JSON after retries
     */
    public function chat(array $messages, array $jsonSchema): array;

    /**
     * Light health check — does not consume quota.
     */
    public function isAvailable(): bool;

    /**
     * Returns the provider slug: "openrouter", "openai", etc.
     */
    public function getProviderName(): string;

    /**
     * Returns the actual model identifier being used.
     */
    public function getModelName(): string;
}
