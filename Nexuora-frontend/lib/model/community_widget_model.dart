class CommunityWidgetModel {
  int?    id;
  int?    userId;
  String? name;
  String? screenData;
  String? previewImage;
  int?    importCount;
  int?    isCommunity;

  CommunityWidgetModel.fromJson(Map<String, dynamic> json) {
    id           = json['id'];
    userId       = json['user_id'];
    name         = json['name'];
    screenData   = json['screen_data'];
    previewImage = json['preview_image'];
    importCount  = json['import_count'] ?? 0;
    isCommunity  = json['is_community'] ?? 0;
  }
}
