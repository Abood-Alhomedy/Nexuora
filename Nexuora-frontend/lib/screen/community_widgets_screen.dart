import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nexuora/model/community_widget_model.dart';
import 'package:nexuora/network/community_widget_api.dart';
import 'package:nexuora/utils/AppFunctions.dart';
import 'package:nexuora/widgets/screen_json_parser_class.dart';



class CommunityWidgetsScreen extends StatefulWidget {
  @override
  _CommunityWidgetsScreenState createState() => _CommunityWidgetsScreenState();
}

class _CommunityWidgetsScreenState extends State<CommunityWidgetsScreen> {
  List<CommunityWidgetModel> widgets = [];
  bool isLoading = true;
  TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWidgets();
  }

  Future<void> _loadWidgets({String? search}) async {
    setState(() => isLoading = true);
    try {
      final res = await getCommunityWidgetList(search: search);
      if (res['status'] == true) {
        widgets = (res['data'] as List)
            .map((e) => CommunityWidgetModel.fromJson(e))
            .toList();
      }
    } catch (e) {
      getToast('حدث خطأ في تحميل القائمة');
    }
    setState(() => isLoading = false);
  }

Future<void> _import(CommunityWidgetModel item) async {
  try {
    final res = await importWidgetApi(item.id!);
    if (res['status'] == true) {
      // الدالة تقبل String مباشرة وليس Map
      await applyScreenJsonToView(res['screen_data'] as String?);
      getToast('تم استيراد ${item.name} بنجاح!');
      Navigator.pop(context);
    }
  } catch (e) {
    getToast('فشل الاستيراد');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('متجر الـ Widgets المجتمعية'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: 'ابحث عن Widget...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
              onSubmitted: (v) => _loadWidgets(search: v),
            ),
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: widgets.length,
              itemBuilder: (ctx, i) {
                final w = widgets[i];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showImportDialog(w),
                    child: Column(
                      children: [
                        // صورة المعاينة
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            child: w.previewImage != null
                                ? Image.network(w.previewImage!, fit: BoxFit.cover, width: double.infinity)
                                : Container(color: Colors.grey[100], child: Icon(Icons.widgets, size: 40, color: Colors.grey)),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(w.name ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(height: 2),
                              Text('${w.importCount} استيراد', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showImportDialog(CommunityWidgetModel item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('استيراد ${item.name}'),
        content: Text('هل تريد إضافة هذا الـ Widget إلى الشاشة الحالية؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          ElevatedButton(onPressed: () => _import(item), child: Text('استيراد')),
        ],
      ),
    );
  }
}
