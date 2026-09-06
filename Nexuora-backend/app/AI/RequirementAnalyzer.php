<?php

namespace App\AI;

use App\AI\LLM\OpenRouterClient;

class RequirementAnalyzer
{
    public function __construct(
        protected OpenRouterClient $llm
    ) {}

    public function analyze(
        string $skill,
        string $references,
        array $projectSchema,
        string $userRequest
    ): array {

        $systemPrompt = <<<PROMPT
You are the Flutter Viz Dart Backend Architect.

Follow the provided skill and references strictly.

The project schema below is authoritative runtime data.

Do not invent project-specific information.

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