class BaseResponse {
  bool? status;
  String? message;
  String? url;
  Data? data;

  BaseResponse({this.status, this.message, this.url, this.data});

  BaseResponse.fromJson(Map<String, dynamic> json) {
    status = json['status'] ?? json['success']; // دعم كل من status و success
    message = json['message'];
    url = json['url'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    data['url'] = url;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  int? id;
  Map<String, dynamic>? extraData; // لإضافة بيانات إضافية

  Data({this.id, this.extraData});

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    extraData = json;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    if (extraData != null) {
      data.addAll(extraData!);
    }
    return data;
  }
}