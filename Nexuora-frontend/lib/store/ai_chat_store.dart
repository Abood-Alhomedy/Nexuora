import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:nb_utils/nb_utils.dart';
import '../model/ai_chat_models.dart';
import '../network/ai_api_client.dart';
import '../services/ai_context_builder.dart';
import '../services/ai_action_executor.dart';
import '../utils/AppConstant.dart';

part 'ai_chat_store.g.dart';

/// AiChatStore — MobX store for the AI Chat panel.
///
/// Responsibilities:
///  - Manage message list (observable)
///  - Call AiApiClient.sendMessage()
///  - On success: call AiActionExecutor.executeBatch() (if no confirmation needed)
///  - On confirm: call AiApiClient.confirmPlan(), then execute
///  - Report results back to backend via AiApiClient.reportResults()
class AiChatStore = _AiChatStoreBase with _$AiChatStore;

abstract class _AiChatStoreBase with Store {
  _AiChatStoreBase({required this.projectId, required this.screenId});

  final int projectId;
  final int? screenId;

  @observable
  int? conversationId;

  @observable
  ObservableList<AiChatMessage> messages = ObservableList<AiChatMessage>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  /// Pending batch awaiting user confirmation
  @observable
  AiChatMessage? pendingConfirmMessage;

  // ─────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────

  @action
  Future<void> sendMessage(String text, BuildContext context) async {
    if (text.trim().isEmpty || isLoading) return;
    errorMessage = null;

    // Add user message to list
    messages.add(AiChatMessage.userMessage(text.trim()));
    // Add loading indicator
    messages.add(AiChatMessage.loading());
    isLoading = true;

    try {
      final token = await getStringAsync(TOKEN);

      // Build UI context (selected widget, screen, etc.)
      final uiCtx = AiContextBuilder.buildUiContext();

      final request = AiChatRequest(
        projectId: projectId,
        message: text.trim(),
        screenId: screenId ?? uiCtx['screen_id'],
        conversationId: conversationId,
        selectedWidgetId: uiCtx['selected_widget_id'],
        selectedWidgetType: uiCtx['selected_widget_type'],
        currentParentWidgetId: uiCtx['current_parent_widget_id'],
      );

      final response = await AiApiClient.sendMessage(request: request, token: token);

      // Remove loading indicator
      messages.removeWhere((m) => m.isLoading);
      isLoading = false;

      // Update conversation ID for multi-turn
      if (response.conversationId != null) {
        conversationId = response.conversationId;
      }

      final assistantMsg = AiChatMessage.fromResponse(response);
      messages.add(assistantMsg);

      // ── Immediate execution (no confirmation needed) ──────────────────
      if (response.hasActions && !response.requiresConfirmation && response.batchId != null) {
        await _executeAndReport(response.actionDescriptors, response.batchId!, context);
      }

      // ── Confirmation required ──────────────────────────────────────────
      if (response.requiresConfirmation) {
        pendingConfirmMessage = assistantMsg;
      }
    } catch (e) {
      messages.removeWhere((m) => m.isLoading);
      isLoading = false;
      messages.add(AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: AiMessageRole.assistant,
        content: 'An error occurred: ${e.toString()}',
        timestamp: DateTime.now(),
        isError: true,
      ));
    }
  }

  @action
  Future<void> confirmPlan(int batchId, List<AiActionDescriptor> pendingDescriptors, BuildContext context) async {
    if (isLoading) return;
    isLoading = true;

    try {
      final token = await getStringAsync(TOKEN);

      // Tell backend it's confirmed
      final confirmResponse = await AiApiClient.confirmPlan(batchId: batchId, token: token);

      isLoading = false;

      if (confirmResponse.hasActions) {
        await _executeAndReport(confirmResponse.actionDescriptors, batchId, context);
        messages.add(AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: AiMessageRole.assistant,
          content: '✅ Done! Changes applied.',
          timestamp: DateTime.now(),
        ));
      }
      pendingConfirmMessage = null;
    } catch (e) {
      isLoading = false;
      errorMessage = 'Failed to confirm: ${e.toString()}';
    }
  }

  @action
  void cancelPlan() {
    pendingConfirmMessage = null;
  }

  @action
  void clearMessages() {
    messages.clear();
    conversationId = null;
    pendingConfirmMessage = null;
    errorMessage = null;
  }

  // ─────────────────────────────────────────────────────────
  // Private
  // ─────────────────────────────────────────────────────────

  Future<void> _executeAndReport(
    List<AiActionDescriptor> descriptors,
    int batchId,
    BuildContext context,
  ) async {
    // Execute via AppStore — single undo-step for the whole batch
    final results = await AiActionExecutor.executeBatch(descriptors, context);

    // Report results back to backend
    final token = await getStringAsync(TOKEN);
    await AiApiClient.reportResults(batchId: batchId, results: results, token: token);
  }
}
