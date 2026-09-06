<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Services\BackendGenerationService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Throwable;

class AIGeneratorController extends Controller
{
    public function __construct(
        protected BackendGenerationService $generationService
    ) {}

    public function generate(
        Request $request
    ): JsonResponse {

        $request->validate([
            'project_id' => [
                'required',
                'integer',
            ],

            'message' => [
                'required',
                'string',
            ],

            'conversation_id' => [
                'nullable',
                'integer',
            ],
        ]);

        try {

            $result = $this->generationService->generate(
                $request->integer('project_id'),
                $request->string('message')->toString(),
                $request->integer('conversation_id')
            );

            return response()->json([
                'status' => true,
                'data' => $result,
            ]);

        } catch (Throwable $e) {

            report($e);

            return response()->json([
                'status' => false,
                'message' => $e->getMessage(),
            ], 500);
        }
    }
}