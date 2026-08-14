import 'package:nexuora/model/base_response.dart' as FB;
import 'package:nexuora/network/rest_apis.dart';
import 'package:nexuora/main.dart';
import 'package:nb_utils/nb_utils.dart';

class LiveDeviceService {
  
  /// تشغيل المشروع
  Future<RunProjectResult> runProject(Map<String, dynamic> projectData) async {
    try {
      Map req = {
        "projectData": projectData,
        "projectId": appStore.projectId,
        "projectName": appStore.projectName,
      };
      
      final FB.BaseResponse response = await runProjectApi(req);
      
      return RunProjectResult(
        success: response.status ?? false,
        message: response.message,
        url: response.url,
        data: response.data?.toJson(),
      );
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
  
  /// الحصول على قائمة الأجهزة
  Future<List<DeviceInfo>> getDevices() async {
    try {
      final FB.BaseResponse response = await getDevicesApi();
      
      if (response.status == true) {
        final data = response.data?.toJson() ?? {};
        List<dynamic> devicesData = data['devices'] ?? [];
        return devicesData.map((e) => DeviceInfo.fromJson(e)).toList();
      } else {
        throw Exception(response.message ?? 'Failed to get devices');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
  
  /// اختيار جهاز
  Future<bool> selectDevice(String deviceId) async {
    try {
      Map req = {"deviceId": deviceId};
      final FB.BaseResponse response = await selectDeviceApi(req);
      
      return response.status ?? false;
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
  
  /// إرسال تحديث مباشر
  Future<bool> sendLiveUpdate(Map<String, dynamic> projectData) async {
    try {
      Map req = {
        "projectData": projectData,
        "projectId": appStore.projectId,
        "screenId": appStore.selectedScreenId,
      };
      
      final FB.BaseResponse response = await liveUpdateApi(req);
      
      return response.status ?? false;
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
  
  /// إيقاف المشروع
  Future<bool> stopProject() async {
    try {
      Map req = {"projectId": appStore.projectId};
      final FB.BaseResponse response = await stopProjectApi(req);
      
      return response.status ?? false;
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
}

/// نتيجة تشغيل المشروع
class RunProjectResult {
  final bool success;
  final String? message;
  final String? url;
  final Map<String, dynamic>? data;
  
  RunProjectResult({
    required this.success,
    this.message,
    this.url,
    this.data,
  });
}

/// معلومات الجهاز
class DeviceInfo {
  final String id;
  final String name;
  final String platform;
  final bool isEmulator;
  
  DeviceInfo({
    required this.id,
    required this.name,
    required this.platform,
    this.isEmulator = false,
  });
  
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] ?? json['deviceId'] ?? '',
      name: json['name'] ?? json['deviceName'] ?? 'Unknown',
      platform: json['platform'] ?? 'Unknown',
      isEmulator: json['isEmulator'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'platform': platform,
      'isEmulator': isEmulator,
    };
  }
}