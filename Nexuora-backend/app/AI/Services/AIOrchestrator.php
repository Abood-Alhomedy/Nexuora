<?php

namespace App\AI\Services;

use App\AI\Contracts\LLMProvider;
use App\AI\Providers\OpenRouterProvider;
use App\AI\Exceptions\AIValidationException;
use App\AI\Exceptions\AIAuthorizationException;
use App\AI\Exceptions\LLMUnavailableException;
use App\AI\Exceptions\RateLimitException;
use App\Models\AiActionBatch;
use App\Models\AiUsage;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;

/**
 * AIOrchestrator — main façade that coordinates the full AI pipeline.
 *
 * Pipeline:
 *  1. Rate limit check
 *  2. Sanitize user input (prompt injection protection)
 *  3. ContextBuilder::build()
 *  4. ConversationManager::loadOrCreate() + history
 *  5. IntentAnalyzer::analyze() via LLMProvider
 *  6. confidence=low → return clarification (no execution)
 *  7. TargetResolver::resolve()
 *  8. missing_parameters → ask user (no execution)
 *  9. Planner::plan()
 * 10. ActionValidator::validateAll() (fail-fast)
 * 11. requires_confirmation → return plan preview (no execution)
 * 12. Save ai_action_batches record
 * 13. Log ai_usage
 * 14. Return action descriptors to AIController → Flutter executes
 *
 * NO PHP widget mutation happens here. Flutter/AppStore executes everything.
 */
class AIOrchestrator
{
    public function __construct(
        private LLMProvider          $llm,
        private ContextBuilder       $contextBuilder,
        private IntentAnalyzer       $intentAnalyzer,
        private TargetResolver       $targetResolver,
        private Planner              $planner,
        private ActionValidator      $actionValidator,
        private ConversationManager  $conversationManager,
        private ProjectMemoryService $memoryService,
    ) {}

    /**
     * Process a user AI chat message.
     *
     * @param  array  $request  Validated request data
     * @return array  API response
     */
    public function process(array $request, int $userId): array
    {

      \Log::debug('[AI DEBUG] Orchestrator Input', [
          'input' => $request,
      ]);
        $startTime    = microtime(true);
        $projectId    = $request['project_id'];
        $screenId     = $request['screen_id'] ?? null;
        $rawMessage   = $request['message'];
        $convId       = $request['conversation_id'] ?? null;
        $uiContext     = $this->extractUiContext($request);

        // ── 1. Rate limit check ──────────────────────────────────────────────
        $this->checkRateLimit($userId);

        // ── 2. Prompt injection protection ──────────────────────────────────
        $message = OpenRouterProvider::sanitizeUserInput($rawMessage);

        // ── 3. Context ───────────────────────────────────────────────────────
        $scope   = $this->determineScope($uiContext, $screenId);
$context = $this->contextBuilder->build(
    $projectId,
    $userId,
    $screenId,
    $uiContext,
    $scope
);

\Log::debug('[AI DEBUG] UI Context', [
    'ui_context' => $uiContext,
]);

\Log::debug('[AI DEBUG] Built Context', [
    'context' => $context,
]);        \Log::debug('[AI DEBUG] Built Context', [
        'context' => $context,
        ]);

        if (isset($context['error'])) {
            return $this->error('project_not_found', 'Project not found or access denied.');
        }

        // ── 4. Conversation ──────────────────────────────────────────────────
        $conversation = $this->conversationManager->loadOrCreate($userId, $projectId, $convId);
        $history      = $this->conversationManager->getHistory(
            $conversation->id,
            config('ai.context.recent_messages', 15)
        );

        // ── 4b. Enrich context with conversation history + project memories ───
        $projectMemories = $this->memoryService->getRelevant($projectId);
        $context = $this->contextBuilder->enrichWithConversationContext(
            $context,
            $conversation->summary,
            $history,
            $projectMemories
        );

        // Append user message
        $userMsg = $this->conversationManager->appendMessage(
            $conversation->id, 'user', $message
        );

              // ── 5. Intent Analysis (LLM call) ────────────────────────────────────
        $usageData = ['provider' => $this->llm->getProviderName(), 'model' => $this->llm->getModelName(),
                      'project_id' => $projectId, 'conversation_id' => $conversation->id,
                      'user_id' => $userId];
        try {
            $multiResult = $this->intentAnalyzer->analyze($message, $context, $history);
            \Log::debug('[AI DEBUG] Multi Intent Result', ['result' => $multiResult]);
        } catch (LLMUnavailableException $e) {
            $this->logUsage($usageData, 'failed', $e->getMessage(), microtime(true) - $startTime);
            return $this->error('llm_unavailable', 'AI service is temporarily unavailable. Please try again.');
        } catch (RateLimitException $e) {
            $this->logUsage($usageData, 'rate_limited', $e->getMessage(), microtime(true) - $startTime);
            return $this->error('rate_limited', 'AI rate limit reached. Please slow down and try again.');
        }

        $tasks = $multiResult['tasks'] ?? [];

        // ── 6. If ALL tasks are low-confidence / CLARIFY / UNKNOWN ──────────
        $executableTasks = array_filter($tasks, fn($t) =>
            ($t['confidence'] ?? 'low') !== 'low' &&
            !in_array($t['intent'] ?? '', ['CLARIFY', 'UNKNOWN'])
        );

        if (empty($executableTasks)) {
            $clarQuestion = $multiResult['clarification_question']
                ?? ($tasks[0]['clarification_question'] ?? null)
                ?? "Could you describe more precisely what you'd like to do?";
            $this->conversationManager->appendMessage($conversation->id, 'assistant', $clarQuestion, 'CLARIFY', 'low');
            return $this->clarificationResponse($conversation->id, $clarQuestion, $tasks[0] ?? []);
        }

        // ── 7-9. Process each executable task ────────────────────────────────
        $allDescriptors      = [];
        $requiresConfirmation = false;
        $planPreviews        = [];
        $actionOffset        = 0;

        foreach ($executableTasks as $taskResult) {
            $intent = $taskResult['intent'];

            // Target resolution
            $targetResult = $this->targetResolver->resolve($taskResult, $context);
            \Log::debug('[AI DEBUG] Task Target Result', ['intent' => $intent, 'target' => $targetResult]);

            // Skip tasks that need clarification about target (don't block other tasks)
            if ($targetResult['matched'] === -1 || $targetResult['matched'] === 0) {
                continue;
            }

            // Skip ambiguous targets
            if ($targetResult['matched'] > 1) {
                continue;
            }

            // Skip tasks with missing parameters
            if (!empty($taskResult['missing_parameters'])) {
                continue;
            }

            // Build plan for this task
            $plan = $this->planner->plan($taskResult, $targetResult, $context, $actionOffset);

            // Validate
            try {
                $this->actionValidator->validateAll($plan['action_descriptors'], $context, $userId);
            } catch (AIValidationException $e) {
                \Log::warning('[AI] Validation failed for task', ['intent' => $intent, 'error' => $e->getErrors()]);
                continue; // skip invalid task, don't block others
            } catch (AIAuthorizationException $e) {
                return $this->error('unauthorized', $e->getMessage());
            }

            // Collect descriptors
            $allDescriptors   = array_merge($allDescriptors, $plan['action_descriptors']);
            $actionOffset     += count($plan['action_descriptors']);
            $planPreviews[]   = $plan['plan_preview'];
            if ($plan['requires_confirmation']) {
                $requiresConfirmation = true;
            }
        }

        if (empty($allDescriptors)) {
            return $this->error('no_executable_tasks', 'Could not extract any executable actions from your message. Please be more specific.');
        }

        // Use first task's intent/confidence for logging
        $firstTask  = array_values($executableTasks)[0];
        $intent     = $firstTask['intent'];
        $confidence = $firstTask['confidence'];

        // ── 11. Confirmation required ─────────────────────────────────────────
        $descriptorsToReturn = $allDescriptors;

        // Save batch record
        $batch = AiActionBatch::create([
            'conversation_id'    => $conversation->id,
            'message_id'         => $userMsg->id,
            'project_id'         => $projectId,
            'screen_id'          => $screenId,
            'status'             => $requiresConfirmation ? 'pending_confirmation' : 'confirmed',
            'action_descriptors' => $descriptorsToReturn,
            'execution_metadata' => ['scope' => $scope, 'intent' => $intent, 'task_count' => count($executableTasks)],
        ]);

        // ── 12. Update conversation state ─────────────────────────────────────
        $this->conversationManager->setCurrentIntent($conversation, $intent);

        $assistantContent = $multiResult['plan_description']
            ?? implode(' | ', $planPreviews);
        if ($requiresConfirmation) {
            $assistantContent .= ' (waiting for your confirmation)';
        }
        $this->conversationManager->appendMessage(
            $conversation->id, 'assistant', $assistantContent, $intent, $confidence,
            ['batch_id' => $batch->id, 'action_count' => count($descriptorsToReturn)]
        );

        // ── 13. Log usage ─────────────────────────────────────────────────────
        $this->logUsage($usageData, 'success', null, microtime(true) - $startTime);

        // ── 14. Post-process ──────────────────────────────────────────────────
        try {
            $this->conversationManager->touchLastMessage($conversation->id);
            $this->memoryService->extractFromAssistantResponse(
                $projectId, $conversation->id, $message, $assistantContent, $this->llm
            );
        } catch (\Throwable $e) {
            Log::warning('[AI] Non-critical post-process error', ['error' => $e->getMessage()]);
        }

        // ── 15. Return to controller ──────────────────────────────────────────
        return [
            'status'               => true,
            'conversation_id'      => $conversation->id,
            'message_id'           => $userMsg->id,
            'batch_id'             => $batch->id,
            'intent'               => $intent,
            'confidence'           => $confidence,
            'message'              => $assistantContent,
            'requires_confirmation'=> $requiresConfirmation,
            'plan_preview'         => $requiresConfirmation ? $assistantContent : null,
            'action_descriptors'   => $requiresConfirmation ? [] : $descriptorsToReturn,
            'pending_descriptors'  => $requiresConfirmation ? $descriptorsToReturn : [],
            'error_type'           => null,
        ];
    }

    /**
     * Confirm a pending plan and release action descriptors to Flutter.
     */
    public function confirm(int $batchId, int $userId): array
    {
        $batch = AiActionBatch::where('id', $batchId)->where('status', 'pending_confirmation')->first();
        if (!$batch) {
            return $this->error('not_found', 'Pending plan not found.');
        }

        // Authorization
        if (!$this->userOwnsBatch($batch, $userId)) {
            return $this->error('unauthorized', 'Access denied.');
        }

        $batch->status = 'confirmed';
        $batch->save();

        return [
            'status'             => true,
            'batch_id'           => $batchId,
            'action_descriptors' => $batch->action_descriptors,
            'error_type'         => null,
        ];
    }

    /**
     * Accept execution results reported back by Flutter.
     */
    public function recordResults(int $batchId, array $results, int $userId): array
    {
        $batch = AiActionBatch::where('id', $batchId)->where('status', 'confirmed')->first();
        if (!$batch) {
            return $this->error('not_found', 'Batch not found or not in confirmed state.');
        }
        if (!$this->userOwnsBatch($batch, $userId)) {
            return $this->error('unauthorized', 'Access denied.');
        }

        $batch->status          = 'executed';
        $batch->action_results  = $results;
        $batch->updated_at      = now();
        $batch->save();

        return ['status' => true, 'batch_id' => $batchId];
    }

    // ─────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────

    private function extractUiContext(array $request): array
    {
        return array_filter([
            'selected_widget_id'         => $request['selected_widget_id'] ?? null,
            'selected_widget_type'       => $request['selected_widget_type'] ?? null,
            'current_parent_widget_id'   => $request['current_parent_widget_id'] ?? null,
        ]);
    }

    private function determineScope(array $uiContext, ?int $screenId): string
    {
        if (!empty($uiContext['selected_widget_id'])) return 'screen';
        if ($screenId) return 'screen';
        return 'full_project';
    }

    private function checkRateLimit(int $userId): void
    {
        $rpm = config('ai.rate_limit.rpm', 10);
        $key = "ai_rpm_{$userId}";

        if (RateLimiter::tooManyAttempts($key, $rpm)) {
            throw new RateLimitException('You are sending requests too quickly. Please slow down.');
        }
        RateLimiter::hit($key, 60);
    }

    private function userOwnsBatch(AiActionBatch $batch, int $userId): bool
    {
        return \App\Models\Project::where('id', $batch->project_id)
            ->where('user_id', $userId)
            ->exists();
    }

    private function logUsage(array $data, string $status, ?string $error, float $elapsedSec): void
    {
        try {
            AiUsage::create([
                'user_id'         => $data['user_id'],
                'project_id'      => $data['project_id'] ?? null,
                'conversation_id' => $data['conversation_id'] ?? null,
                'provider'        => $data['provider'],
                'model'           => $data['model'],
                'input_tokens'    => 0,  // OpenRouter free tier may not return token counts
                'output_tokens'   => 0,
                'latency_ms'      => (int) ($elapsedSec * 1000),
                'request_count'   => 1,
                'status'          => $status,
                'error_type'      => $error ? substr($error, 0, 255) : null,
            ]);
        } catch (\Throwable $e) {
            Log::warning('[AI] Failed to log usage', ['error' => $e->getMessage()]);
        }
    }

    private function error(string $type, string $message): array
    {
        return [
            'status'               => false,
            'conversation_id'      => null,
            'message_id'           => null,
            'batch_id'             => null,
            'intent'               => null,
            'confidence'           => null,
            'message'              => $message,
            'requires_confirmation'=> false,
            'plan_preview'         => null,
            'action_descriptors'   => [],
            'pending_descriptors'  => [],
            'error_type'           => $type,
        ];
    }

    private function clarificationResponse(int $convId, string $question, array $intentResult, array $candidates = []): array
    {
        return [
            'status'               => true,
            'conversation_id'      => $convId,
            'message_id'           => null,
            'batch_id'             => null,
            'intent'               => $intentResult['intent'],
            'confidence'           => $intentResult['confidence'],
            'message'              => $question,
            'requires_confirmation'=> false,
            'plan_preview'         => null,
            'action_descriptors'   => [],
            'pending_descriptors'  => [],
            'candidates'           => $candidates,
            'error_type'           => 'clarification_needed',
        ];
    }

    private function ambiguousTargetResponse(int $convId, string $question, array $candidates): array
    {
        return [
            'status'               => true,
            'conversation_id'      => $convId,
            'message_id'           => null,
            'batch_id'             => null,
            'intent'               => null,
            'confidence'           => null,
            'message'              => $question,
            'requires_confirmation'=> false,
            'plan_preview'         => null,
            'action_descriptors'   => [],
            'pending_descriptors'  => [],
            'candidates'           => $candidates,
            'error_type'           => 'ambiguous_target',
        ];
    }
}
