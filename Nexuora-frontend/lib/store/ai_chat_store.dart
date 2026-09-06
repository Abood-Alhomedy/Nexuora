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
///  - Load conversation history from backend on open (persistent)
///  - Create new conversations explicitly via API
///  - Call AiApiClient.sendMessage()
///  - On success: call AiActionExecutor.executeBatch() (if no confirmation needed)
///  - On confirm: call AiApiClient.confirmPlan(), then execute
///  - Report results back to backend via AiApiClient.reportResults()
class AiChatStore = _AiChatStoreBase with _$AiChatStore;

abstract class _AiChatStoreBase with Store {
  _AiChatStoreBase({required this.projectId, required this.screenId});

  final int projectId;
  final int? screenId;

  // ─────────────────────────────────────────────────────────
  // Observables
  // ─────────────────────────────────────────────────────────

  @observable
  int? conversationId;

  @observable
  ObservableList<AiChatMessage> messages = ObservableList<AiChatMessage>();

  @observable
  bool isLoading = false;

  @observable
  bool isLoadingHistory = false;

  @observable
  String? errorMessage;

  /// Pending batch awaiting user confirmation
  @observable
  AiChatMessage? pendingConfirmMessage;

  /// List of conversations for this project (for the sidebar)
  @observable
  ObservableList<Map<String, dynamic>> conversationList =
      ObservableList<Map<String, dynamic>>();

  // ─────────────────────────────────────────────────────────
  // Persistent conversation management
  // ─────────────────────────────────────────────────────────

  /// Called from initState.
  /// Loads the most recent conversation for this project, or creates one.
  @action
  Future<void> loadOrCreateLastConversation() async {
    isLoadingHistory = true;
    errorMessage = null;
    try {
      final token = await getStringAsync(TOKEN);

      // 1. Fetch all conversations for this project
      final conversations = await AiApiClient.getConversations(
        projectId: projectId,
        token: token,
      );

      // Store list for sidebar (reversed: newest first)
      conversationList = ObservableList.of(conversations.reversed.toList());

      if (conversations.isNotEmpty) {
        // 2a. Load the most recent conversation
        final latest = conversations.last;
        await loadConversation(latest['id'] as int, token: token);
      } else {
        // 2b. Create a fresh conversation (no messages yet)
        await createNewConversation();
      }
    } catch (e) {
      // Non-fatal: just start with empty session
      debugPrint('[AiChatStore] loadOrCreateLastConversation failed: $e');
    } finally {
      isLoadingHistory = false;
    }
  }

  /// Load a specific conversation by ID and populate messages.
  @action
  Future<void> loadConversation(int convId, {String? token}) async {
    try {
      final t = token ?? await getStringAsync(TOKEN);
      final rawMessages = await AiApiClient.getMessages(
        conversationId: convId,
        token: t,
      );

      conversationId = convId;
      messages.clear();
      pendingConfirmMessage = null;

      for (final raw in rawMessages) {
        final role = raw['role'] == 'user'
            ? AiMessageRole.user
            : AiMessageRole.assistant;
        messages.add(AiChatMessage(
          id: raw['id'].toString(),
          role: role,
          content: raw['content'] ?? '',
          timestamp: raw['created_at'] != null
              ? DateTime.tryParse(raw['created_at'].toString()) ?? DateTime.now()
              : DateTime.now(),
        ));
      }
    } catch (e) {
      debugPrint('[AiChatStore] loadConversation($convId) failed: $e');
    }
  }

  /// Create a brand-new conversation via API and switch to it.
  @action
  Future<void> createNewConversation() async {
    try {
      final token = await getStringAsync(TOKEN);
      final data = await AiApiClient.createConversation(
        projectId: projectId,
        token: token,
      );

      if (data != null) {
        conversationId = data['id'] as int?;
        // Add to sidebar list at the front
        conversationList.insert(0, data);
      } else {
        // Fallback: reset to empty session without a persisted ID
        conversationId = null;
      }

      messages.clear();
      pendingConfirmMessage = null;
      errorMessage = null;
    } catch (e) {
      debugPrint('[AiChatStore] createNewConversation failed: $e');
      // Gracefully start fresh in memory
      conversationId = null;
      messages.clear();
    }
  }

  /// Switch to a different conversation (from sidebar tap).
  @action
  Future<void> switchConversation(int convId) async {
    if (convId == conversationId) return;
    messages.clear();
    pendingConfirmMessage = null;
    errorMessage = null;
    await loadConversation(convId);
  }

  /// Remove a conversation from the sidebar list after deletion.
  @action
  void removeConversationFromList(int convId) {
    conversationList.removeWhere((c) => c['id'] == convId);
    // If we deleted the currently active one, reset
    if (conversationId == convId) {
      conversationId = null;
      messages.clear();
    }
  }

  // ─────────────────────────────────────────────────────────
  // Messaging actions
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
        userId:1,
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

  /// Clear messages from the UI only.
  /// Does NOT reset conversationId — that would break backend continuity.
  @action
  void clearMessages() {
    messages.clear();
    // NOTE: conversationId intentionally kept — do NOT reset here.
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
