import 'dart:convert';

import 'package:nexuora/model/base_response.dart' as FB;
import 'package:nexuora/network/network_utils.dart';
import 'package:http/http.dart';
import 'package:nexuora/utils/AppConstant.dart';

// ─── Models ────────────────────────────────────────────────────

/// معلومات جهاز Android مكتشَف
class WiFiDevice {
  final String id;
  final String name;
  final String status;
  final bool isWifi;
  final bool isEmulator;

  WiFiDevice({
    required this.id,
    required this.name,
    this.status = 'device',
    this.isWifi = true,
    this.isEmulator = false,
  });

  factory WiFiDevice.fromJson(Map<String, dynamic> j) => WiFiDevice(
        id:         j['id']         ?? '',
        name:       j['name']       ?? j['id'] ?? 'Unknown',
        status:     j['status']     ?? 'device',
        isWifi:     j['isWifi']     ?? true,
        isEmulator: j['isEmulator'] ?? false,
      );

  bool get isReady => status == 'device';

  @override
  String toString() => '$name ($id)';
}

/// نتيجة عملية تشغيل المشروع
class RunResult {
  final bool success;
  final String? message;
  final String? deviceId;
  final int?    pid;
  final String? logFile;

  RunResult({
    required this.success,
    this.message,
    this.deviceId,
    this.pid,
    this.logFile,
  });
}

// ─── Service ───────────────────────────────────────────────────

/// خدمة تشغيل مشاريع Flutter على أجهزة Android عبر Wi-Fi ADB
class WiFiDeviceService {

  // ── 1. اتصال بجهاز عبر IP ────────────────────────────────────

  Future<WiFiDevice> connect({
    required String ip,
    int port = 5555,
  }) async {
    final resp = await buildHttpResponse(
      'wifi-device/connect',
      request: {'ip': ip, 'port': port},
      method: HttpMethod.POST,
    );
    final json = await handleResponse(resp);
    final data = json['data'] as Map<String, dynamic>? ?? {};

    if (json['status'] == true) {
      return WiFiDevice(
        id:   data['deviceId'] ?? '$ip:$port',
        name: ip,
      );
    }
    throw Exception(json['message'] ?? 'Connection failed');
  }

  // ── 2. قطع الاتصال ───────────────────────────────────────────

  Future<void> disconnect(String deviceId) async {
    final resp = await buildHttpResponse(
      'wifi-device/disconnect',
      request: {'deviceId': deviceId},
      method: HttpMethod.POST,
    );
    await handleResponse(resp);
  }

  // ── 3. قائمة الأجهزة المتصلة ─────────────────────────────────

  Future<List<WiFiDevice>> getDevices() async {
    final resp = await buildHttpResponse(
      'wifi-device/devices',
      method: HttpMethod.GET,
    );
    final json = await handleResponse(resp);
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final list = data['devices'] as List<dynamic>? ?? [];
    return list
        .map((e) => WiFiDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── 3-B. اكتشاف تلقائي عبر USB ──────────────────────────────

  /// يتصل عبر USB → يقرأ الـ IP تلقائياً → يُفعّل TCP/IP → يتصل Wi-Fi
  Future<List<WiFiDevice>> detectFromUsb() async {
    final resp = await buildHttpResponse(
      'wifi-device/detect-usb',
      method: HttpMethod.GET,
    );
    final json = await handleResponse(resp);
    if (json['status'] != true) {
      throw Exception(json['message'] ?? 'USB detection failed');
    }
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final list = data['devices'] as List<dynamic>? ?? [];
    return list
        .map((e) => WiFiDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }


  // ── 4. تشغيل المشروع ─────────────────────────────────────────

  Future<RunResult> run({
    required int    projectId,
    required String projectName,
    required String deviceId,
    required List<Map<String, dynamic>> screens,
  }) async {
    final resp = await buildHttpResponse(
      'wifi-device/run',
      request: {
        'projectId':   projectId,
        'projectName': projectName,
        'deviceId':    deviceId,
        'screens':     screens,
      },
      method: HttpMethod.POST,
    );
    final json = await handleResponse(resp);
    final data = json['data'] as Map<String, dynamic>? ?? {};

    return RunResult(
      success:  json['status'] == true,
      message:  json['message'],
      deviceId: data['deviceId'],
      pid:      data['pid'] is int ? data['pid'] : null,
      logFile:  data['logFile'],
    );
  }

  // ── 5. Hot Reload ─────────────────────────────────────────────

  Future<bool> hotReload({
    required int projectId,
    required List<Map<String, dynamic>> screens,
  }) async {
    final resp = await buildHttpResponse(
      'wifi-device/hot-reload',
      request: {'projectId': projectId, 'screens': screens},
      method: HttpMethod.POST,
    );
    final json = await handleResponse(resp);
    return json['status'] == true;
  }

  // ── 6. إيقاف التشغيل ─────────────────────────────────────────

  Future<bool> stop(int projectId) async {
    final resp = await buildHttpResponse(
      'wifi-device/stop',
      request: {'projectId': projectId},
      method: HttpMethod.POST,
    );
    final json = await handleResponse(resp);
    return json['status'] == true;
  }
}
