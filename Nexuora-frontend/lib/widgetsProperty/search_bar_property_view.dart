import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nexuora/main.dart'; // مسار الـ AppStore
import 'package:nexuora/utils/AppWidget.dart';
import 'package:nexuora/widgetsClass/search_bar_class.dart';
import 'package:nexuora/widgetsProperty/comman_property_view.dart';
import 'package:nb_utils/nb_utils.dart';

class SearchBarPropertyView extends StatefulWidget {
  @override
  _SearchBarPropertyViewState createState() => _SearchBarPropertyViewState();
}

class _SearchBarPropertyViewState extends State<SearchBarPropertyView> {
  late SearchBarClass searchBarClass;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    // جلب البيانات المخزنة من العنصر المحدد حالياً
    searchBarClass =
        appStore.currentSelectedWidget!.widgetViewModel as SearchBarClass;
  }

  @override
  Widget build(BuildContext context) {
    init();
    return Observer(
      builder: (context) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Search Bar Properties", style: boldTextStyle(size: 16)),
              16.height,

              // تغيير النص
              Text("Hint Text", style: primaryTextStyle()),
              8.height,
              AppTextField(
                controller:
                    TextEditingController(text: searchBarClass.hintText),
                textFieldType: TextFieldType.OTHER,
                onChanged: (val) {
                  searchBarClass.hintText = val;
                  appStore.updateData(searchBarClass);
                },
              ),
              16.height,

              // تغيير اللون
              ExpansionTileView(
                language!.backgroundColor,
                context,
                <Widget>[
                  ColorView(
                    color: searchBarClass.backgroundColor ?? Colors.grey[200]!,
                    applyColor: () {
                      searchBarClass.backgroundColor = appStore.color;
                      
                      setState(() {});
                      appStore.updateData(searchBarClass);
                    },
                    pickColor: () {
                      showColorPicker(context, searchBarClass.backgroundColor ?? Colors.grey[200]!, applyOnWidget: (color) {
                        searchBarClass.backgroundColor = color;
                        setState(() {});
                        appStore.updateData(searchBarClass);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
