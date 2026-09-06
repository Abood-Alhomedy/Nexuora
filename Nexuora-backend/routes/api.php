<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\API\ScreenController;
use App\Http\Controllers\API\ProjectController;
use App\Http\Controllers\API\UserController;
use App\Http\Controllers\API\CategoryController;
use App\Http\Controllers\API\CommanController;
use App\Http\Controllers\API\ComponentController;
use App\Http\Controllers\API\AI\AIController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/
use App\Http\Controllers\API\AIGeneratorController;

Route::middleware('auth:sanctum')->get('/user', function (Request $request) {
    return $request->user();
});

Route::post('login', [UserController::class, 'login']);
Route::post('forgot-password', [UserController::class, 'forgot']);
Route::post('register', [UserController::class, 'register']);
Route::post('google-register', [UserController::class, 'googleRegister']);

Route::get('category-list', [CategoryController::class, 'categoryList']);

Route::post('country-list', [CommanController::class, 'getCountryList']);
Route::post('state-list', [CommanController::class, 'getStateList']);
Route::post('city-list', [CommanController::class, 'getCityList']);

Route::middleware('auth:sanctum')->group(function () {

    Route::post('update-profile', [UserController::class, 'updateProfile']);
    Route::post('update-profile-image', [UserController::class, 'updateProfileImage']);
    Route::post('change-password', [UserController::class, 'changePassword']);
    Route::get('user-list', [UserController::class, 'userList']);
    Route::post('save-user-file', [UserController::class, 'saveUserFiles']);
    Route::post('download-user-project', [UserController::class, 'downloadUserProject']);
    Route::post('build-user-apk', [UserController::class, 'buildUserApk']);

    Route::get('project-list', [ProjectController::class, 'projectList']);
    Route::post('project-save', [ProjectController::class, 'store']);
    Route::post('project-delete', [ProjectController::class, 'Delete']);
    Route::post('update-project-time', [ProjectController::class, 'projectLastTime']);
    Route::post('project-clone', [ProjectController::class, 'projectClone']);

    Route::get('screen-list', [ScreenController::class, 'screenList']);
    Route::post('screen-save', [ScreenController::class, 'store']);
    Route::post('screen-delete', [ScreenController::class, 'Delete']);

    // Community Widgets
    Route::post('save-user-widget',      [ComponentController::class, 'saveUserWidget']);
    Route::get('community-widget-list',  [ComponentController::class, 'communityWidgetList']);
    Route::post('import-widget',         [ComponentController::class, 'importWidget']);

    // ── AI App Builder ────────────────────────────────────────
    Route::prefix('ai')->group(function () {
        Route::post('chat',                          [AIController::class, 'chat']);
        Route::post('chat/{batch_id}/confirm',       [AIController::class, 'confirmPlan']);
        Route::post('chat/{batch_id}/apply-results', [AIController::class, 'applyResults']);
        Route::post('conversations',                 [AIController::class, 'createConversation']);
        Route::get('conversations',                  [AIController::class, 'conversationList']);
        Route::get('conversations/{id}/messages',    [AIController::class, 'messageList']);
        Route::delete('conversations/{id}',          [AIController::class, 'deleteConversation']);
        Route::get('health',                         [AIController::class, 'health']);
    });
    
Route::post(
    '/ai/backend/generate',
    [AIGeneratorController::class, 'generate']
);


});