import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../model/backend_chat_models.dart';
import '../utils/AppConstant.dart';

class BackendApiClient {
  static String get _base {
    final b = baseURl ?? '';
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }

  /// POST /api/ai/backend/generate
  static Future<BackendGenerateResponse> generate({
    required BackendGenerateRequest request,
    required String token,
  }) async {
    final uri = Uri.parse('$_base/ai/backend/generate');

    debugPrint('========== BACKEND GENERATE REQUEST ==========');
    debugPrint(jsonEncode(request.toJson()));
    debugPrint('==============================================');

    final response = await http
        .post(
          uri,
          headers: _headers(token),
          body: jsonEncode(request.toJson()),
        )
        .timeout(const Duration(seconds: 120));

    debugPrint('========== BACKEND GENERATE RESPONSE ==========');
    debugPrint(response.body);
    debugPrint('===============================================');

    return BackendGenerateResponse.fromJson(jsonDecode(response.body));
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
}