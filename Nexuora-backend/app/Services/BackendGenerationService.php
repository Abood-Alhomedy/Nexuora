<?php

namespace App\Services;

use App\AI\BackendGenerator;
use App\AI\ProjectSchemaService;
use App\Models\AiConversation;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\File;
use RuntimeException;

class BackendGenerationService
{
    public function __construct(
        protected ProjectSchemaService $schemaService,
        protected BackendGenerator $generator
    ) {}


    /**
     * Generate backend files from AI response.
     */
    public function generate(
        int $projectId,
        string $userRequest,
        ?int $conversationId = null
    ): array {

        /*
        |--------------------------------------------------------------------------
        | Conversation
        |--------------------------------------------------------------------------
        */

        if ($conversationId) {

            $conversation = AiConversation::query()
                ->where('id', $conversationId)
                ->where('project_id', $projectId)
                ->firstOrFail();

        } else {

            $user = Auth::user();

            if (!$user) {
                throw new RuntimeException(
                    'Unauthenticated user.'
                );
            }

            $conversation = AiConversation::create([
                'user_id' => $user->id,
                'project_id' => $projectId,
                'title' => 'Backend Generation',
                'current_intent' => 'backend_generation',
                'metadata' => [],
                'last_message_at' => now(),
            ]);
        }


        /*
        |--------------------------------------------------------------------------
        | Save user message
        |--------------------------------------------------------------------------
        */

        $conversation->messages()->create([
            'role' => 'user',
            'content' => $userRequest,
        ]);


        /*
        |--------------------------------------------------------------------------
        | Get authoritative schema
        |--------------------------------------------------------------------------
        */

        $schema = $this->schemaService
            ->getProjectSchema($projectId);


        /*
        |--------------------------------------------------------------------------
        | Get conversation context
        |--------------------------------------------------------------------------
        */

        $conversationContext = $conversation
            ->messages()
            ->orderBy('created_at')
            ->get([
                'role',
                'content',
            ])
            ->map(function ($message) {

                return [
                    'role' => $message->role,
                    'content' => $message->content,
                ];

            })
            ->values()
            ->toArray();


        /*
        |--------------------------------------------------------------------------
        | Load skill
        |--------------------------------------------------------------------------
        */

        $skillPath = resource_path(
            'ai/skills/backend-generation/SKILL.md'
        );

        if (!File::exists($skillPath)) {

            throw new RuntimeException(
                "Skill file not found: {$skillPath}"
            );
        }

        $skill = File::get($skillPath);


        /*
        |--------------------------------------------------------------------------
        | Load references
        |--------------------------------------------------------------------------
        */

        $references = $this->loadReferences();


        /*
        |--------------------------------------------------------------------------
        | Ask LLM
        |--------------------------------------------------------------------------
        */

        $result = $this->generator->generate(
            $skill,
            $references,
            $schema,
            $userRequest,
            $conversationContext
        );


        /*
        |--------------------------------------------------------------------------
        | Validate response
        |--------------------------------------------------------------------------
        */

        $this->validateLLMResponse($result);


        /*
        |--------------------------------------------------------------------------
        | Handle clarification
        |--------------------------------------------------------------------------
        */

        if ($result['status'] === 'needs_clarification') {

            $conversation->messages()->create([
                'role' => 'assistant',
                'content' => json_encode(
                    $result,
                    JSON_UNESCAPED_UNICODE |
                    JSON_UNESCAPED_SLASHES
                ),
            ]);

            $conversation->update([
                'last_message_at' => now(),
            ]);

            $result['conversation_id'] = $conversation->id;

            return $result;
        }


        /*
        |--------------------------------------------------------------------------
        | Handle error response
        |--------------------------------------------------------------------------
        */

        if ($result['status'] === 'error') {

            throw new RuntimeException(
                $result['message']
                    ?? 'LLM generation failed.'
            );
        }


        /*
        |--------------------------------------------------------------------------
        | Validate successful response
        |--------------------------------------------------------------------------
        */

        if ($result['status'] !== 'success') {

            throw new RuntimeException(
                "Unexpected LLM status: {$result['status']}"
            );
        }


        /*
        |--------------------------------------------------------------------------
        | Validate project ID
        |--------------------------------------------------------------------------
        */

        if ((int) $result['project_id'] !== $projectId) {

            throw new RuntimeException(
                'LLM response project ID does not match requested project.'
            );
        }


        /*
        |--------------------------------------------------------------------------
        | Validate AI validation result
        |--------------------------------------------------------------------------
        */

        if (
            isset($result['validation']['valid']) &&
            $result['validation']['valid'] === false
        ) {

            $errors = $result['validation']['errors'] ?? [];

            throw new RuntimeException(
                'LLM generated invalid backend: ' .
                implode(', ', $errors)
            );
        }


        /*
        |--------------------------------------------------------------------------
        | Prepare project from FlutterViz template
        |--------------------------------------------------------------------------
        */

        $projectPath = $this->prepareProjectDirectory(
            $projectId
        );


        /*
        |--------------------------------------------------------------------------
        | Handle generated backend files
        |--------------------------------------------------------------------------
        */

        $generatedFiles = $this->handleGeneratedFiles(
            $projectPath,
            $result['files']
        );


        /*
        |--------------------------------------------------------------------------
        | Add generated files to response
        |--------------------------------------------------------------------------
        */

        $result['generated_files'] = $generatedFiles;

        $result['project_path'] = $projectPath;


        /*
        |--------------------------------------------------------------------------
        | Save assistant message
        |--------------------------------------------------------------------------
        */

        $conversation->messages()->create([
            'role' => 'assistant',
            'content' => json_encode(
                $result,
                JSON_UNESCAPED_UNICODE |
                JSON_UNESCAPED_SLASHES
            ),
        ]);


        /*
        |--------------------------------------------------------------------------
        | Update conversation
        |--------------------------------------------------------------------------
        */

        $conversation->update([
            'last_message_at' => now(),
        ]);


        /*
        |--------------------------------------------------------------------------
        | Add conversation ID
        |--------------------------------------------------------------------------
        */

        $result['conversation_id'] = $conversation->id;


        return $result;
    }


    /**
     * Prepare project directory by copying FlutterViz template.
     *
     * Source:
     * storage/app/public/flutterviz
     *
     * Destination:
     * storage/app/projects/{projectId}/flutterviz
     */
    protected function prepareProjectDirectory(
        int $projectId
    ): string {

        /*
        |--------------------------------------------------------------------------
        | Template path
        |--------------------------------------------------------------------------
        */

        $templatePath = storage_path(
            'app/public/flutterviz'
        );


        /*
        |--------------------------------------------------------------------------
        | Validate template
        |--------------------------------------------------------------------------
        */

        if (!File::isDirectory($templatePath)) {

            throw new RuntimeException(
                "FlutterViz template not found: {$templatePath}"
            );
        }


        /*
        |--------------------------------------------------------------------------
        | Project base directory
        |--------------------------------------------------------------------------
        */

        $projectBasePath = storage_path(
            "app/projects/{$projectId}"
        );


        /*
        |--------------------------------------------------------------------------
        | Project FlutterViz directory
        |--------------------------------------------------------------------------
        */

        $projectPath = $projectBasePath .
            DIRECTORY_SEPARATOR .
            'flutterviz';


        /*
        |--------------------------------------------------------------------------
        | Copy template only once
        |--------------------------------------------------------------------------
        */

        if (!File::exists($projectPath)) {

            /*
            |----------------------------------------------------------------------
            | Create base directory
            |----------------------------------------------------------------------
            */

            if (!File::exists($projectBasePath)) {

                File::makeDirectory(
                    $projectBasePath,
                    0755,
                    true
                );
            }


            /*
            |----------------------------------------------------------------------
            | Copy template
            |----------------------------------------------------------------------
            */

            $copied = File::copyDirectory(
                $templatePath,
                $projectPath
            );


            if (!$copied) {

                throw new RuntimeException(
                    'Failed to copy FlutterViz template.'
                );
            }
        }


        /*
        |--------------------------------------------------------------------------
        | Ensure backend directory exists
        |--------------------------------------------------------------------------
        */

        $backendPath = $projectPath .
            DIRECTORY_SEPARATOR .
            'backend';


        if (!File::exists($backendPath)) {

            File::makeDirectory(
                $backendPath,
                0755,
                true
            );
        }


        return $projectPath;
    }


    /**
     * Handle generated backend files.
     */
    protected function handleGeneratedFiles(
        string $projectPath,
        array $files
    ): array {

        /*
        |--------------------------------------------------------------------------
        | Backend directory
        |--------------------------------------------------------------------------
        */

        $backendBasePath = $projectPath .
            DIRECTORY_SEPARATOR .
            'backend';


        /*
        |--------------------------------------------------------------------------
        | Processed files
        |--------------------------------------------------------------------------
        */

        $processedFiles = [];


        /*
        |--------------------------------------------------------------------------
        | Process files
        |--------------------------------------------------------------------------
        */

        foreach ($files as $file) {

            /*
            |----------------------------------------------------------------------
            | Validate structure
            |----------------------------------------------------------------------
            */

            if (
                !isset($file['path']) ||
                !isset($file['action'])
            ) {

                throw new RuntimeException(
                    'Invalid generated file structure.'
                );
            }


            /*
            |----------------------------------------------------------------------
            | Normalize path
            |----------------------------------------------------------------------
            */

            $relativePath = str_replace(
                '\\',
                '/',
                ltrim(
                    trim($file['path']),
                    '/\\'
                )
            );


            $action = strtolower(
                trim($file['action'])
            );


            $content = $file['content'] ?? '';


            /*
            |----------------------------------------------------------------------
            | Security: prevent directory traversal
            |----------------------------------------------------------------------
            */

            if (
                str_contains($relativePath, '../') ||
                str_starts_with($relativePath, '..')
            ) {

                throw new RuntimeException(
                    "Invalid file path: {$relativePath}"
                );
            }


            /*
            |----------------------------------------------------------------------
            | Remove backend prefix
            |----------------------------------------------------------------------
            |
            | AI can return:
            |
            | backend/lib/models/user.dart
            |
            | OR:
            |
            | lib/models/user.dart
            |
            */

            if (
                str_starts_with(
                    $relativePath,
                    'backend/'
                )
            ) {

                $backendRelativePath = substr(
                    $relativePath,
                    strlen('backend/')
                );

            } else {

                $backendRelativePath = $relativePath;
            }


            /*
            |----------------------------------------------------------------------
            | Validate relative path
            |----------------------------------------------------------------------
            */

            if (empty($backendRelativePath)) {

                throw new RuntimeException(
                    'Generated file path cannot be empty.'
                );
            }


            /*
            |----------------------------------------------------------------------
            | Final path
            |----------------------------------------------------------------------
            */

            $fullPath = $backendBasePath .
                DIRECTORY_SEPARATOR .
                str_replace(
                    '/',
                    DIRECTORY_SEPARATOR,
                    $backendRelativePath
                );


            /*
            |----------------------------------------------------------------------
            | Security check
            |----------------------------------------------------------------------
            */

            $normalizedBackendPath = realpath(
                $backendBasePath
            );

            $normalizedDirectory = realpath(
                dirname($fullPath)
            );


            /*
            |----------------------------------------------------------------------
            | CREATE DIRECTORY
            |----------------------------------------------------------------------
            */

            $directory = dirname($fullPath);

            if (!File::exists($directory)) {

                File::makeDirectory(
                    $directory,
                    0755,
                    true
                );
            }


            /*
            |----------------------------------------------------------------------
            | CREATE FILE
            |----------------------------------------------------------------------
            */

            if ($action === 'create') {

                File::put(
                    $fullPath,
                    $content
                );


                $processedFiles[] = [
                    'path' => 'backend/' . $backendRelativePath,
                    'action' => 'created',
                ];

                continue;
            }


            /*
            |----------------------------------------------------------------------
            | UPDATE FILE
            |----------------------------------------------------------------------
            */

            if ($action === 'update') {

                File::put(
                    $fullPath,
                    $content
                );


                $processedFiles[] = [
                    'path' => 'backend/' . $backendRelativePath,
                    'action' => 'updated',
                ];

                continue;
            }


            /*
            |----------------------------------------------------------------------
            | Invalid action
            |----------------------------------------------------------------------
            */

            throw new RuntimeException(
                "Unsupported file action: {$action}"
            );
        }


        return $processedFiles;
    }


    /**
     * Load AI references.
     */
    protected function loadReferences(): string
    {
        $directory = resource_path(
            'ai/references'
        );


        $files = [
            'architecture.md',
            'generation-rules.md',
            'project-schema-contract.md',
            'output-contract.md',
        ];


        $content = '';


        foreach ($files as $file) {

            $path = $directory .
                DIRECTORY_SEPARATOR .
                $file;


            if (!File::exists($path)) {

                throw new RuntimeException(
                    "Reference file not found: {$file}"
                );
            }


            $content .= "\n\n";

            $content .= "# {$file}\n";

            $content .= File::get($path);
        }


        return $content;
    }


    /**
     * Validate LLM response according to Output Contract.
     */
    protected function validateLLMResponse(
        array $result
    ): void {

        /*
        |--------------------------------------------------------------------------
        | Required top-level fields
        |--------------------------------------------------------------------------
        */

        $requiredFields = [
            'status',
            'project_id',
            'analysis',
            'questions',
            'files',
            'validation',
        ];


        foreach ($requiredFields as $field) {

            if (!array_key_exists($field, $result)) {

                throw new RuntimeException(
                    "LLM response missing required field: {$field}"
                );
            }
        }


        /*
        |--------------------------------------------------------------------------
        | Validate status
        |--------------------------------------------------------------------------
        */

        $allowedStatuses = [
            'success',
            'needs_clarification',
            'error',
        ];


        if (!in_array(
            $result['status'],
            $allowedStatuses,
            true
        )) {

            throw new RuntimeException(
                "Invalid LLM status: {$result['status']}"
            );
        }


        /*
        |--------------------------------------------------------------------------
        | Validate project ID
        |--------------------------------------------------------------------------
        */

        if (!is_numeric($result['project_id'])) {

            throw new RuntimeException(
                'LLM response project_id must be numeric.'
            );
        }


        /*
        |--------------------------------------------------------------------------
        | Validate analysis
        |--------------------------------------------------------------------------
        */

        if (!is_array($result['analysis'])) {

            throw new RuntimeException(
                'LLM response analysis must be an object.'
            );
        }


        /*
        |--------------------------------------------------------------------------
        | Validate questions
        |--------------------------------------------------------------------------
        */

        if (!is_array($result['questions'])) {

            throw new RuntimeException(
                'LLM response questions must be an array.'
            );
        }


        /*
        |--------------------------------------------------------------------------
        | Validate files
        |--------------------------------------------------------------------------
        */

        if (!is_array($result['files'])) {

            throw new RuntimeException(
                'LLM response files must be an array.'
            );
        }


        /*
        |--------------------------------------------------------------------------
        | Validate validation object
        |--------------------------------------------------------------------------
        */

        if (!is_array($result['validation'])) {

            throw new RuntimeException(
                'LLM response validation must be an object.'
            );
        }


        if (
            !array_key_exists(
                'valid',
                $result['validation']
            )
        ) {

            throw new RuntimeException(
                'LLM response validation missing valid field.'
            );
        }


        if (
            !array_key_exists(
                'errors',
                $result['validation']
            )
        ) {

            throw new RuntimeException(
                'LLM response validation missing errors field.'
            );
        }


        /*
        |--------------------------------------------------------------------------
        | Validate files items
        |--------------------------------------------------------------------------
        */

        foreach ($result['files'] as $file) {

            if (!is_array($file)) {

                throw new RuntimeException(
                    'Invalid generated file format.'
                );
            }


            /*
            |----------------------------------------------------------------------
            | Required file fields
            |----------------------------------------------------------------------
            */

            foreach ([
                'path',
                'action',
                'content',
            ] as $field) {

                if (!array_key_exists($field, $file)) {

                    throw new RuntimeException(
                        "Generated file missing {$field}."
                    );
                }
            }


            /*
            |----------------------------------------------------------------------
            | Validate action
            |----------------------------------------------------------------------
            */

            $allowedActions = [
                'create',
                'update',
            ];


            if (!in_array(
                strtolower($file['action']),
                $allowedActions,
                true
            )) {

                throw new RuntimeException(
                    "Invalid file action: {$file['action']}"
                );
            }
        }
    }
}
