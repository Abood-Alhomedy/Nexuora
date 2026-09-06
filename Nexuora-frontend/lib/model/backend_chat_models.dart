// نماذج بيانات شات الباك اند

enum BackendMessageRole { user, assistant }

class BackendChatMessage {
  final String id;
  final BackendMessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isLoading;
  final bool isError;
  final List<Map<String, dynamic>> generatedFiles;
  final String? analysis;
  final List<String> questions;

  BackendChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isLoading = false,
    this.isError = false,
    this.generatedFiles = const [],
    this.analysis,
    this.questions = const [],
  });

  factory BackendChatMessage.userMessage(String text) => BackendChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: BackendMessageRole.user,
        content: text,
        timestamp: DateTime.now(),
      );

  factory BackendChatMessage.loading() => BackendChatMessage(
        id: 'loading',
        role: BackendMessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
        isLoading: true,
      );
}

class BackendGenerateRequest {
  final int projectId;
  final String message;
  final int? conversationId;

  BackendGenerateRequest({
    required this.projectId,
    required this.message,
    this.conversationId,
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
      };
}

class BackendGenerateResponse {
  final String status; // success | needs_clarification | error
  final int? conversationId;
  final String? analysis;
  final List<String> questions;
  final List<Map<String, dynamic>> generatedFiles;
  final String? message; // for error/clarification

  BackendGenerateResponse({
    required this.status,
    this.conversationId,
    this.analysis,
    this.questions = const [],
    this.generatedFiles = const [],
    this.message,
  });

  factory BackendGenerateResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return BackendGenerateResponse(
      status: data['status'] as String? ?? 'error',
      conversationId: data['conversation_id'] as int?,
      analysis: data['analysis'] as String?,
      questions: List<String>.from(data['questions'] ?? []),
      generatedFiles:
          List<Map<String, dynamic>>.from(data['generated_files'] ?? []),
      message: data['message'] as String?,
    );
  }

  bool get isSuccess => status == 'success';
  bool get needsClarification => status == 'needs_clarification';
}