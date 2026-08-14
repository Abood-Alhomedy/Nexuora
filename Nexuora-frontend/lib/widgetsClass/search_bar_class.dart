import 'package:flutter/material.dart';
import 'package:nexuora/model/widget_model.dart'; // تأكد من المسار حسب مشروعك
import 'package:nexuora/utils/AppConstant.dart';
import 'package:nexuora/utils/AppFunctions.dart';
import 'package:nexuora/widgets/widgets.dart';

class SearchBarClass {
  String? hintText;
  Color? backgroundColor;
  double? borderRadius;

  SearchBarClass({
    this.hintText = "Search...",
    this.backgroundColor,
    this.borderRadius = 8.0,
  });

  SearchBarClass.fromJson(Map<String, dynamic> json) {
    hintText = json['hintText'] ?? "Search...";
    backgroundColor = json['backgroundColor'] != null ? Color(json['backgroundColor']) : null;
    borderRadius = json['borderRadius'] ?? 8.0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['hintText'] = this.hintText;
    if (backgroundColor != null) data['backgroundColor'] = this.backgroundColor!.value;
    data['borderRadius'] = this.borderRadius;
    return data;
  }

  // الواجهة التي تظهر في وضع التصميم (Canvas)
  Widget getDefaultSearchBarWidget(WidgetModel widgetModel) {
    Widget childData = AbsorbPointer(
      absorbing: absorbPointer(),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.grey[200],
          borderRadius: BorderRadius.circular(borderRadius!),
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(Icons.search),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
    return getGestureDetector(widgetModel, childData); // ليكون قابلاً للتحديد في المحرر
  }

  // الكود الذي يتم إنتاجه عند الضغط على تصدير التطبيق View Code
  String getSearchBarString() {
    String bg = backgroundColor != null ? "Color(0x${backgroundColor!.value.toRadixString(16).padLeft(8, '0')})" : "Colors.grey[200]";
    return """
Container(
  decoration: BoxDecoration(
    color: $bg,
    borderRadius: BorderRadius.circular($borderRadius),
  ),
  child: TextField(
    decoration: InputDecoration(
      hintText: "$hintText",
      prefixIcon: Icon(Icons.search),
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  ),
)
""";
  }
}