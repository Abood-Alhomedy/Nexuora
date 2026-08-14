<?php

namespace App\Http\Controllers\API\AI;

use App\AI\Providers\OpenRouterProvider;
use App\AI\Registry\WidgetRegistry;
use App\AI\Services\AIOrchestrator;
use App\AI\Services\ContextBuilder;
use App\AI\Services\IntentAnalyzer;
use App\AI\Services\TargetResolver;
use App\AI\Services\Planner;
use App\AI\Services\ActionValidator;
use App\AI\Services\ConversationManager;
use App\Models\AiConversation;
use App\Models\AiMessage;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Validator;

class AIController
{
    private AIOrchestrator $orchestrator;

    public function __construct()
    {
        // Manual dependency injection — no IoC container binding needed yet
        $llm          = new OpenRouterProvider();
        $contextB     = new ContextBuilder();
        $intentA      = new IntentAnalyzer($llm);
        $targetR      = new TargetResolver();
        $planner      = new Planner();
        $validator    = new ActionValidator();
        $convManager  = new ConversationManager();

        $this->orchestrator = new AIOrchestrator(
            $llm, $contextB, $intentA, $targetR, $planner, $validator, $convManager
        );
    }

    /**
     * POST /api/ai/chat
     * Main endpoint — process a user message.
     */
    public function chat(Request $request): JsonResponse
    {
        \Log::debug('[AI DEBUG] Incoming AI Request', [
         'all' => $request->all(),
        ]);

      
        if (!config('ai.enabled', true)) {
            return response()->json(['status' => false, 'message' => 'AI features are disabled.'], 503);
        }

        $v = Validator::make($request->all(), [
            'project_id'               => 'required|integer',
            'message'                  => 'required|string|min:1|max:2000',
            'screen_id'                => 'nullable|integer',
            'conversation_id'          => 'nullable|integer',
            'selected_widget_id'       => 'nullable|string|max:50',
            'selected_widget_type'     => 'nullable|string|max:50',
            'current_parent_widget_id' => 'nullable|string|max:50',
        ]);

        if ($v->fails()) {
            return response()->json(['status' => false, 'message' => 'Validation failed.', 'errors' => $v->errors()], 422);
        }

        $userId = $request->user()->id;

        // DEBUG: log incoming request data temporarily
        \Illuminate\Support\Facades\Log::debug('[AI DEBUG] Raw incoming payload: ' . $request->getContent());
        \Illuminate\Support\Facades\Log::debug('[AI DEBUG] Incoming chat request parsed', [
            'project_id'           => $request->input('project_id'),
            'selected_widget_id'   => $request->input('selected_widget_id'),
            'selected_widget_type' => $request->input('selected_widget_type'),
            'message'              => $request->input('message'),
        ]);

        \Log::debug('[AI DEBUG] Sending to Orchestrator', [
         'payload' => $request->all(),
         ]);

$result = $this->orchestrator->process($request->all(), $userId);
        $result = $this->orchestrator->process($request->all(), $userId);

        $httpCode = $result['status'] ? 200 : 400;
        if (in_array($result['error_type'] ?? '', ['unauthorized'])) $httpCode = 403;

        return response()->json($result, $httpCode);
    }

    /**
     * POST /api/ai/chat/{batch_id}/confirm
     * User confirms a pending plan → releases action_descriptors to Flutter.
     */
    public function confirmPlan(Request $request, int $batchId): JsonResponse
    {
        $result = $this->orchestrator->confirm($batchId, $request->user()->id);
        return response()->json($result, $result['status'] ? 200 : 400);
    }

    /**
     * POST /api/ai/chat/{batch_id}/apply-results
     * Flutter reports execution results back after running ActionDescriptors.
     */
    public function applyResults(Request $request, int $batchId): JsonResponse
    {
        $v = Validator::make($request->all(), [
            'results'                 => 'required|array',
            'results.*.action_id'     => 'required|string',
            'results.*.type'          => 'required|string',
            'results.*.status'        => 'required|string|in:success,failed,skipped',
            'results.*.target_id'     => 'nullable|string',
            'results.*.created_id'    => 'nullable|string',
        ]);

        if ($v->fails()) {
            return response()->json(['status' => false, 'errors' => $v->errors()], 422);
        }

        $result = $this->orchestrator->recordResults($batchId, $request->input('results'), $request->user()->id);
        return response()->json($result);
    }

    /**
     * GET /api/ai/conversations?project_id=X
     * List AI conversations for a project.
     */
    public function conversationList(Request $request): JsonResponse
    {
        $userId    = $request->user()->id;
        $projectId = $request->query('project_id');

        $query = AiConversation::where('user_id', $userId)
            ->withCount('messages')
            ->orderByDesc('updated_at');

        if ($projectId) {
            $query->where('project_id', $projectId);
        }

        $conversations = $query->get(['id', 'project_id', 'title', 'current_intent', 'created_at', 'updated_at']);

        return response()->json(['status' => true, 'data' => $conversations]);
    }

    /**
     * GET /api/ai/conversations/{id}/messages
     * Return message history for a conversation.
     */
    public function messageList(Request $request, int $id): JsonResponse
    {
        $userId = $request->user()->id;

        $conversation = AiConversation::where('id', $id)->where('user_id', $userId)->first();
        if (!$conversation) {
            return response()->json(['status' => false, 'message' => 'Conversation not found.'], 404);
        }

        $messages = AiMessage::where('conversation_id', $id)
            ->orderBy('created_at')
            ->get(['id', 'role', 'content', 'intent', 'confidence', 'created_at']);

        return response()->json(['status' => true, 'data' => $messages]);
    }

    /**
     * DELETE /api/ai/conversations/{id}
     */
    public function deleteConversation(Request $request, int $id): JsonResponse
    {
        $userId = $request->user()->id;
        $deleted = AiConversation::where('id', $id)->where('user_id', $userId)->delete();

        return response()->json(['status' => (bool) $deleted]);
    }

    /**
     * GET /api/ai/health
     * Provider health check.
     */
    public function health(Request $request): JsonResponse
    {
        $llm       = new OpenRouterProvider();
        $available = $llm->isAvailable();

        return response()->json([
            'status'    => true,
            'available' => $available,
            'provider'  => $llm->getProviderName(),
            'model'     => $llm->getModelName(),
            'enabled'   => config('ai.enabled', true),
        ]);
    }
}
