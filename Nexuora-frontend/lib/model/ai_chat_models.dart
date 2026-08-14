/// AI Chat Models — data models for Flutter AI App Builder client
///
/// These models represent the request/response contract between
/// Flutter and the Laravel AI backend.
///
/// IMPORTANT: All widget mutations happen in Flutter via AppStore.
/// The backend only returns ActionDescriptors — Flutter executes them.

// ─── Request ─────────────────────────────────────────────────────────────────

class AiChatRequest {
  final int projectId;
  final String message;
  final int? screenId;
  final int? conversationId;
  final String? selectedWidgetId;
  final String? selectedWidgetType;
  final String? currentParentWidgetId;

  const AiChatRequest({
    required this.projectId,
    required this.message,
    this.screenId,
    this.conversationId,
    this.selectedWidgetId,
    this.selectedWidgetType,
    this.currentParentWidgetId,
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'message': message,
        if (screenId != null) 'screen_id': screenId,
        if (conversationId != null) 'conversation_id': conversationId,
        if (selectedWidgetId != null) 'selected_widget_id': selectedWidgetId,
        if (selectedWidgetType != null) 'selected_widget_type': selectedWidgetType,
        if (currentParentWidgetId != null)
          'current_parent_widget_id': currentParentWidgetId,
      };
}

// ─── Action Descriptor ───────────────────────────────────────────────────────

/// Represents a single AI-generated action that Flutter/AppStore will execute.
/// new_widget_id is always null from the backend — Flutter generates via getWidgetId().
class AiActionDescriptor {
  final String actionId;
  final String type;
  final Map<String, dynamic> target;
  final Map<String, dynamic> payload;

  const AiActionDescriptor({
    required this.actionId,
    required this.type,
    required this.target,
    required this.payload,
  });

  factory AiActionDescriptor.fromJson(Map<String, dynamic> json) {
    return AiActionDescriptor(
      actionId: json['action_id'] ?? '',
      type: json['type'] ?? '',
      target: Map<String, dynamic>.from(json['target'] ?? {}),
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'action_id': actionId,
        'type': type,
        'target': target,
        'payload': payload,
      };

  /// Widget type for ADD_WIDGET actions
  String? get widgetType => payload['widget_type'] as String?;

  /// Target widget ID for existing widget operations
  String? get targetWidgetId => target['widget_id'] as String?;

  /// Parent ID for ADD_WIDGET
  String? get parentId => target['parent_id'] as String?;

  /// Properties map for UPDATE_WIDGET
  Map<String, dynamic> get properties =>
      Map<String, dynamic>.from(payload['properties'] ?? {});
}

// ─── Action Result ────────────────────────────────────────────────────────────

/// Reported back to backend after Flutter executes an ActionDescriptor.
class AiActionResult {
  final String actionId;
  final String type;
  final String status; // 'success' | 'failed' | 'skipped'
  final String? targetId;
  final String? createdId; // the actual widget ID assigned by getWidgetId()
  final String? error;

  const AiActionResult({
    required this.actionId,
    required this.type,
    required this.status,
    this.targetId,
    this.createdId,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'action_id': actionId,
        'type': type,
        'status': status,
        if (targetId != null) 'target_id': targetId,
        if (createdId != null) 'created_id': createdId,
        if (error != null) 'error': error,
      };
}

// ─── Response ─────────────────────────────────────────────────────────────────

class AiChatResponse {
  final bool status;
  final int? conversationId;
  final int? messageId;
  final int? batchId;
  final String? intent;
  final String? confidence; // 'high' | 'medium' | 'low'
  final String message;
  final bool requiresConfirmation;
  final String? planPreview;
  final List<AiActionDescriptor> actionDescriptors;
  final List<AiActionDescriptor> pendingDescriptors;
  final List<Map<String, dynamic>> candidates; // for ambiguous target
  final String? errorType;

  const AiChatResponse({
    required this.status,
    this.conversationId,
    this.messageId,
    this.batchId,
    this.intent,
    this.confidence,
    required this.message,
    this.requiresConfirmation = false,
    this.planPreview,
    this.actionDescriptors = const [],
    this.pendingDescriptors = const [],
    this.candidates = const [],
    this.errorType,
  });

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    List<AiActionDescriptor> parseDescriptors(dynamic list) {
      if (list == null || list is! List) return [];
      return list.map((e) => AiActionDescriptor.fromJson(Map<String, dynamic>.from(e))).toList();
    }

    return AiChatResponse(
      status: json['status'] == true,
      conversationId: json['conversation_id'] as int?,
      messageId: json['message_id'] as int?,
      batchId: json['batch_id'] as int?,
      intent: json['intent'] as String?,
      confidence: json['confidence'] as String?,
      message: json['message'] as String? ?? '',
      requiresConfirmation: json['requires_confirmation'] == true,
      planPreview: json['plan_preview'] as String?,
      actionDescriptors: parseDescriptors(json['action_descriptors']),
      pendingDescriptors: parseDescriptors(json['pending_descriptors']),
      candidates: List<Map<String, dynamic>>.from(
        (json['candidates'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? [],
      ),
      errorType: json['error_type'] as String?,
    );
  }

  bool get hasActions => actionDescriptors.isNotEmpty;
  bool get needsClarification => errorType == 'clarification_needed' || errorType == 'ambiguous_target';
  bool get isError => !status && errorType != null && errorType != 'clarification_needed';
}

// ─── Chat Message (UI model) ──────────────────────────────────────────────────

enum AiMessageRole { user, assistant }

class AiChatMessage {
  final String id;
  final AiMessageRole role;
  final String content;
  final DateTime timestamp;
  final String? intent;
  final int? batchId;
  final List<AiActionDescriptor> pendingDescriptors;
  final bool requiresConfirmation;
  final String? planPreview;
  final List<Map<String, dynamic>> candidates;
  final bool isLoading;
  final bool isError;

  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.intent,
    this.batchId,
    this.pendingDescriptors = const [],
    this.requiresConfirmation = false,
    this.planPreview,
    this.candidates = const [],
    this.isLoading = false,
    this.isError = false,
  });

  static AiChatMessage fromResponse(AiChatResponse response) {
    return AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: AiMessageRole.assistant,
      content: response.message,
      timestamp: DateTime.now(),
      intent: response.intent,
      batchId: response.batchId,
      pendingDescriptors: response.pendingDescriptors,
      requiresConfirmation: response.requiresConfirmation,
      planPreview: response.planPreview,
      candidates: response.candidates,
      isError: response.isError,
    );
  }

  static AiChatMessage userMessage(String content) {
    return AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: AiMessageRole.user,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  static AiChatMessage loading() {
    return AiChatMessage(
      id: 'loading',
      role: AiMessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isLoading: true,
    );
  }

  AiChatMessage copyWith({bool? isLoading, bool? isError, String? content}) {
    return AiChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      intent: intent,
      batchId: batchId,
      pendingDescriptors: pendingDescriptors,
      requiresConfirmation: requiresConfirmation,
      planPreview: planPreview,
      candidates: candidates,
      isLoading: isLoading ?? this.isLoading,
      isError: isError ?? this.isError,
    );
  }
}
