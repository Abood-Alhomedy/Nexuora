<?php

namespace App\AI;

use App\AI\LLM\OpenRouterClient;
use App\Models\AiConversation;
class BackendGenerator
{
    public function __construct(
        protected OpenRouterClient $llm
    ) {}

    public function generate(
        string $skill,
        string $references,
        array $projectSchema,
        string $userRequest,
        array $conversationContext = []
        
    ): array {


        // Build conversation context
        $conversationText = '';

        foreach ($conversationContext as $message) {

            $role = strtoupper(
                $message['role'] ?? 'unknown'
            );

            $content = $message['content'] ?? '';

            $conversationText .= "[{$role}]\n";
            $conversationText .= $content;
            $conversationText .= "\n\n";
          }
        $systemPrompt = <<<PROMPT
You are the Flutter Viz Dart Backend Generator.

Generate Dart backend code only.

Follow the skill and references strictly.

Never invent project data.

The database project schema is authoritative.
CONVERSATION CONTEXT:
{$conversationText}

SKILL:
{$skill}

REFERENCES:
{$references}

PROJECT SCHEMA:
PROMPT;

        $systemPrompt .= json_encode(
            $projectSchema,
            JSON_PRETTY_PRINT |
            JSON_UNESCAPED_UNICODE
        );

        return $this->llm->chatCompletionJson(
            $systemPrompt,
            $userRequest
        );
    }
}