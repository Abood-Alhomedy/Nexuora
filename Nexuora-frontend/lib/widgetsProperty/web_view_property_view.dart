import 'package:nexuora/main.dart';
import 'package:nexuora/widgetsClass/web_view_class.dart';
import 'package:nexuora/widgetsProperty/comman_property_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WebViewPropertyView extends StatefulWidget {
  static String tag = '/WebViewPropertyView';

  @override
  WebViewPropertyViewState createState() => WebViewPropertyViewState();
}

class WebViewPropertyViewState extends State<WebViewPropertyView> {
  var webViewClass;

  init() async {
    webViewClass = appStore.currentSelectedWidget!.widgetViewModel as WebViewClass?;
  }

  @override
  Widget build(BuildContext context) {
    init();
    return Column(
      children: [
        ExpansionTileView(
          language!.url,
          context,
          <Widget>[
            getTextField(
              controller: TextEditingController(text: webViewClass.url != null ? webViewClass.url.toString() : "https://flutter.dev/"),
              hint: "Enter Url",
              onChanged: (s) {
                webViewClass.url = s;
                appStore.updateData(webViewClass);
              },
            ),
          ],
        )
      ],
    );
  }
}
