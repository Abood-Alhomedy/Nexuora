import 'dart:convert';
import 'package:nexuora/network/network_utils.dart';

// ① حفظ Widget في السيرفر
Future<void> saveUserWidgetApi(Map<String, dynamic> request) async {
  await handleResponse(
    await buildHttpResponse('save-user-widget', request: request, method: HttpMethod.POST),
  );
}

// ② جلب قائمة الـ Community Widgets
Future<Map<String, dynamic>> getCommunityWidgetList({String? search}) async {
  String url = 'community-widget-list';
  if (search != null && search.isNotEmpty) url += '?search=$search';

  return await handleResponse(
    await buildHttpResponse(url, method: HttpMethod.GET),
  );
}

// ③ استيراد Widget داخل المشروع
Future<Map<String, dynamic>> importWidgetApi(int widgetId) async {
  return await handleResponse(
    await buildHttpResponse('import-widget', request: {'id': widgetId}, method: HttpMethod.POST),
  );
}
