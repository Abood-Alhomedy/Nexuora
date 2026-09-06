import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/ai_chat_models.dart';
import '../utils/AppConstant.dart';
import 'package:flutter/foundation.dart';
/// AiApiClient — HTTP client for the Laravel AI backend.
///
/// IMPORTANT: This client communicates with Laravel only.
/// It NEVER calls OpenRouter directly. The API key stays on the backend.
class AiApiClient {
  static String get _base {
    final b = baseURl ?? '';
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }



/// POST /api/ai/chat — send a user message.
static Future<AiChatResponse> sendMessage({
  required AiChatRequest request,
  required String token,
}) async {

  debugPrint('🔥🔥🔥 SEND MESSAGE CALLED 🔥🔥🔥');

  final uri = Uri.parse('$_base/ai/chat');

  final requestBody = request.toJson();

  debugPrint('========== AI REQUEST ==========');
  debugPrint(jsonEncode(requestBody));
  debugPrint('================================');

  final response = await http
      .post(
        uri,
        headers: _headers(token),
        body: jsonEncode(requestBody),
      )
      .timeout(const Duration(seconds: 60));

  debugPrint('========== AI RESPONSE ==========');
  debugPrint(response.body);
  debugPrint('=================================');

  return AiChatResponse.fromJson(jsonDecode(response.body));
}

  /// POST /api/ai/chat/{batch_id}/confirm — user confirms a pending plan.
  static Future<AiChatResponse> confirmPlan({
    required int batchId,
    required String token,
  }) async {
    final uri = Uri.parse('$_base/ai/chat/$batchId/confirm');
    final response = await http
        .post(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 30));

    return AiChatResponse.fromJson(jsonDecode(response.body));
  }

  /// POST /api/ai/chat/{batch_id}/apply-results — report execution results to backend.
  static Future<bool> reportResults({
    required int batchId,
    required List<AiActionResult> results,
    required String token,
  }) async {
    final uri = Uri.parse('$_base/ai/chat/$batchId/apply-results');
    final response = await http
        .post(
          uri,
          headers: _headers(token),
          body: jsonEncode({
            'results': results.map((r) => r.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 30));

    final body = jsonDecode(response.body);
    return body['status'] == true;
  }

  /// GET /api/ai/conversations?project_id=X
  static Future<List<Map<String, dynamic>>> getConversations({
    required int projectId,
    required String token,
  }) async {
    final uri = Uri.parse('$_base/ai/conversations?project_id=$projectId');
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);
    if (body['status'] == true) {
      return List<Map<String, dynamic>>.from(body['data'] ?? []);
    }
    return [];
  }

  /// GET /api/ai/conversations/{id}/messages
  static Future<List<Map<String, dynamic>>> getMessages({
    required int conversationId,
    required String token,
  }) async {
    final uri = Uri.parse('$_base/ai/conversations/$conversationId/messages');
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);
    if (body['status'] == true) {
      return List<Map<String, dynamic>>.from(body['data'] ?? []);
    }
    return [];
  }

  /// DELETE /api/ai/conversations/{id}
  static Future<bool> deleteConversation({
    required int conversationId,
    required String token,
  }) async {
    final uri = Uri.parse('$_base/ai/conversations/$conversationId');
    final response = await http
        .delete(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);
    return body['status'] == true;
  }

  /// POST /api/ai/conversations — explicitly create a new conversation.
  static Future<Map<String, dynamic>?> createConversation({
    required int projectId,
    required String token,
  }) async {
    final uri = Uri.parse('$_base/ai/conversations');
    final response = await http
        .post(
          uri,
          headers: _headers(token),
          body: jsonEncode({'project_id': projectId}),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);
    if (body['status'] == true) {
      return Map<String, dynamic>.from(body['data'] ?? {});
    }
    return null;
  }

  /// GET /api/ai/health
  static Future<Map<String, dynamic>> checkHealth({required String token}) async {
    final uri = Uri.parse('$_base/ai/health');
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 10));
    return jsonDecode(response.body);
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
}
