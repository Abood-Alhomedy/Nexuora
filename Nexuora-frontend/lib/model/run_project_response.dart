import 'package:nexuora/model/base_response.dart';

class RunProjectResponse {
  final bool success;
  final String? message;
  final String? deviceId;
  final String? deviceName;
  final String? url;
  final String? projectId;
  final Map<String, dynamic>? data;
  
  RunProjectResponse({
    required this.success,
    this.message,
    this.deviceId,
    this.deviceName,
    this.url,
    this.projectId,
    this.data,
  });
  
  factory RunProjectResponse.fromJson(Map<String, dynamic> json) {
    return RunProjectResponse(
      success: json['success'] ?? json['status'] ?? false,
      message: json['message'],
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      url: json['url'],
      projectId: json['projectId'],
      data: json,
    );
  }
  
  factory RunProjectResponse.fromBaseResponse(BaseResponse response) {
    return RunProjectResponse(
      success: response.status ?? false,
      message: response.message,
      url: response.url,
      data: response.data?.toJson(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'url': url,
      'projectId': projectId,
    };
  }
}