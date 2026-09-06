import 'dart:convert';
import 'dart:html' as webFile;

import 'package:nexuora/components/add_page_dialog.dart';
import 'package:nexuora/externalClasses/on_hover.dart';
import 'package:nexuora/main.dart';
import 'package:nexuora/model/download_model.dart';
import 'package:nexuora/model/screen_list_response.dart';
import 'package:nexuora/network/community_widget_api.dart';
import 'package:nexuora/network/rest_apis.dart';
import 'package:nexuora/screen/community_widgets_screen.dart';
import 'package:nexuora/screen/ai_chat_screen.dart';
import 'package:nexuora/screen/preview_screen.dart';
import 'package:nexuora/screen/welcome_screen.dart';
import 'package:nexuora/utils/AppColors.dart';
import 'package:nexuora/utils/AppCommon.dart';
import 'package:nexuora/utils/AppCommonApiCall.dart';
import 'package:nexuora/utils/AppConstant.dart';
import 'package:nexuora/utils/AppFunctions.dart';
import 'package:nexuora/utils/AppWidget.dart';
import 'package:nexuora/widgets/screen_json_parser_class.dart';
import 'package:nexuora/widgets/widgets.dart';
import 'package:nexuora/widgetsProperty/comman_property_view.dart';
//import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nexuora/screen/community_widgets_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:nb_utils/nb_utils.dart';

import '../model/models.dart';
import 'feedback_dialog.dart';

import 'dart:convert';
import 'dart:html' as webFile;
import '../screen/ai_chat_screen.dart';
import '../screen/backend_chat_screen.dart';

class HeaderComponent extends StatefulWidget {
  @override
  _HeaderComponentState createState() => _HeaderComponentState();
}

class _HeaderComponentState extends State<HeaderComponent> {
  TextEditingController screenController = TextEditingController();
  bool isDarkMode = appStore.isDarkMode;

  ///download Project latest api
  Future<void> downloadProjectLatest() async {
    appStore.setProjectDownloading(true);
    List<Map> contents = [];

    await Future.forEach<ScreenListData>(appStore.screenList, (element) async {
      appStore.codeViewData.clear();
      appStore.headerImport.clear();
      appStore.yamlImportLib.clear();

      DownloadModel aDownloadModel = await applyScreenJsonToView(
          element.screenJsonData,
          isForDownload: true);
      aDownloadModel.fileName = element.name;
      List<String> filesContent = await viewFinalSourceData(
          aDownloadModel.selectedWidgetList,
          downloadModel: aDownloadModel);

      String codeContent = "";

      for (int i = 0; i < filesContent.length; i++) {
        codeContent = codeContent + filesContent[i];
      }

      log('codeContent $codeContent');
      log('name ${getFileName(projectFileName: aDownloadModel.fileName)}.dart');

      contents.add({
        'file_name':
            "${getFileName(projectFileName: aDownloadModel.fileName)}.dart",
        'file_content': codeContent,
      });
    });

    /// Other Files
    if (appStore.headerImport.length > 0) {
      await Future.forEach<String>(appStore.headerImport, (element) async {
        String fileName = element
            .replaceAll("import ", "")
            .replaceAll("'", "")
            .replaceAll(";", "");
        String fileContent = await loadFileContent(fileName);

        fileContent =
            fileContent.replaceAll("package:flutter_viz/externalClasses/", '');

        contents.add({
          'file_name': fileName,
          'file_content': fileContent,
        });
      });
    }

    /// Add main.dart starting screen
    if (appStore.screenList.isNotEmpty) {
      ScreenListData targetScreen = appStore.screenList.firstWhere(
        (s) =>
            s.name.validate().toLowerCase().contains("home") ||
            s.name.validate().toLowerCase().contains("main"),
        orElse: () {
          return appStore.screenList.firstWhere(
            (s) =>
                s.screenJsonData != null &&
                s.screenJsonData!.isNotEmpty &&
                s.screenJsonData != "{}",
            orElse: () => appStore.screenList.first,
          );
        },
      );

      String firstScreenClass = getFileName(projectFileName: targetScreen.name);
      String mainContent = '''import 'package:flutter/material.dart';
import '$firstScreenClass.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${appStore.projectName.validate()}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: $firstScreenClass(),
    );
  }
}
''';

      contents.add({
        'file_name': 'main.dart',
        'file_content': mainContent,
      });
    }

    Map req = {
      "project_name": appStore.projectName.validate(),
      "is_project_delete": true,
      "is_project_zip": true,
      "contents": contents,
    };

    log(req);
    downloadProjectLatestApi(req).then((value) {
      appStore.setProjectDownloading(false);

      trackUserEvent(DOWNLOAD_PROJECT_CODE);
      appStore.setProjectDownloading(false);
      webFile.AnchorElement(
        href: value.url,
      )
        ..setAttribute("download", "${appStore.projectName}")
        ..click();
    }).catchError((e) {
      appStore.setProjectDownloading(false);
      log("latest project download here$e");
    });
  }

  /// Build APK Latest
  Future<void> buildProjectApkLatest() async {
    appStore.setApkBuilding(true);
    List<Map> contents = [];

    await Future.forEach<ScreenListData>(appStore.screenList, (element) async {
      appStore.codeViewData.clear();
      appStore.headerImport.clear();
      appStore.yamlImportLib.clear();

      DownloadModel aDownloadModel = await applyScreenJsonToView(
          element.screenJsonData,
          isForDownload: true);
      aDownloadModel.fileName = element.name;
      List<String> filesContent = await viewFinalSourceData(
          aDownloadModel.selectedWidgetList,
          downloadModel: aDownloadModel);

      String codeContent = "";

      for (int i = 0; i < filesContent.length; i++) {
        codeContent = codeContent + filesContent[i];
      }

      contents.add({
        'file_name':
            "${getFileName(projectFileName: aDownloadModel.fileName)}.dart",
        'file_content': codeContent,
      });
    });

    /// Other Files
    if (appStore.headerImport.length > 0) {
      await Future.forEach<String>(appStore.headerImport, (element) async {
        String fileName = element
            .replaceAll("import ", "")
            .replaceAll("'", "")
            .replaceAll(";", "");
        String fileContent = await loadFileContent(fileName);

        fileContent =
            fileContent.replaceAll("package:flutter_viz/externalClasses/", '');

        contents.add({
          'file_name': fileName,
          'file_content': fileContent,
        });
      });
    }

    /// Add main.dart starting screen
    if (appStore.screenList.isNotEmpty) {
      ScreenListData targetScreen = appStore.screenList.firstWhere(
        (s) =>
            s.name.validate().toLowerCase().contains("home") ||
            s.name.validate().toLowerCase().contains("main"),
        orElse: () {
          return appStore.screenList.firstWhere(
            (s) =>
                s.screenJsonData != null &&
                s.screenJsonData!.isNotEmpty &&
                s.screenJsonData != "{}",
            orElse: () => appStore.screenList.first,
          );
        },
      );

      String firstScreenClass = getFileName(projectFileName: targetScreen.name);
      String mainContent = '''import 'package:flutter/material.dart';
import '$firstScreenClass.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${appStore.projectName.validate()}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: $firstScreenClass(),
    );
  }
}
''';

      contents.add({
        'file_name': 'main.dart',
        'file_content': mainContent,
      });
    }

    Map req = {
      "project_name": appStore.projectName.validate(),
      "contents": contents,
    };

    getToast("جاري بناء التطبيق بصيغة APK، قد يستغرق ذلك بضع دقائق...");

    buildProjectApkApi(req).then((value) {
      appStore.setApkBuilding(false);

      if (value.url != null && value.url!.isNotEmpty) {
        getToast("تم بناء التطبيق بنجاح!");
        webFile.AnchorElement(
          href: value.url,
        )
          ..setAttribute("download", "${appStore.projectName}.apk")
          ..click();
      } else {
        getToast("فشل بناء التطبيق.");
      }
    }).catchError((e) {
      appStore.setApkBuilding(false);
      getToast("حدث خطأ أثناء بناء الـ APK: " + e.toString());
    });
  }

  ///add template api call
  Future<void> addTemplateApi(Map rootScreenDataJson) async {
    hideKeyboard(context);
    appStore.setLoading(true);
    String? screenImage;
    screenshotController
        .capture(delay: Duration(milliseconds: 10))
        .then((capturedImage) async {
      if (rootScreenDataJson['widgetsData'].isNotEmpty ||
          rootScreenDataJson['appBarData'].isNotEmpty ||
          rootScreenDataJson['bottomBarNavigationData'].isNotEmpty ||
          rootScreenDataJson['drawerData'].isNotEmpty) {
        screenImage = base64.encode(capturedImage!);
      }

      Map req = {
        "id": appStore.screenTemplateData!.id,
        "name": appStore.screenTemplateData!.name,
        "category_id": appStore.screenTemplateData!.categoryId,
        "status": appStore.screenTemplateData!.status,
        "screen_data": json.encode(rootScreenDataJson),
        "template_image": screenImage,
      };
      await addTemplate(req).then((value) {
        appStore.setLoading(false);
        getToast(value.message!);
      }).catchError((e) {
        appStore.setLoading(false);
        getToast(e.toString());
      });
    }).catchError((onError) {
      print(onError);
    });
  }

  ///add component api call
  Future<void> addComponentApi(Map rootScreenDataJson) async {
    hideKeyboard(context);
    appStore.setLoading(true);
    Map req = {
      "id": appStore.screenTemplateData!.id,
      "name": appStore.screenTemplateData!.name,
      "category_id": appStore.screenTemplateData!.categoryId,
      "status": appStore.screenTemplateData!.status,
      "screen_data": json.encode(rootScreenDataJson),
    };

    await addComponent(req).then((value) {
      appStore.setLoading(false);
      getToast(value.message!);
    }).catchError((e) {
      appStore.setLoading(false);
      getToast(e.toString());
    });
  }

  ///addProjectTemplateApi call
  Future<void> addProjectTemplateApi(Map rootScreenDataJson) async {
    hideKeyboard(context);
    appStore.setLoading(true);
    String? screenImage;
    screenshotController
        .capture(delay: Duration(milliseconds: 10))
        .then((capturedImage) async {
      if (rootScreenDataJson['widgetsData'].isNotEmpty ||
          rootScreenDataJson['appBarData'].isNotEmpty ||
          rootScreenDataJson['bottomBarNavigationData'].isNotEmpty ||
          rootScreenDataJson['drawerData'].isNotEmpty) {
        screenImage = base64.encode(capturedImage!);
      }
      Map req = {
        "id": appStore.screenTemplateData!.id,
        "name": appStore.screenTemplateData!.name,
        "status": appStore.screenTemplateData!.status,
        "project_template_id": appStore.screenTemplateData!.projectTemplateId,
        "data": json.encode(rootScreenDataJson),
        "project_template_screen_image": screenImage,
      };
      await addProjectTemplate(req).then((value) {
        appStore.setLoading(false);
        LiveStream().emit(getUpdatedData, true);
        getToast(value.message!);
      }).catchError((e) {
        appStore.setLoading(false);
        getToast(e.toString());
      });
    }).catchError((onError) {
      print(onError);
    });
  }

  ///downloadProject call
  Future<void> downloadProjectApi(
      {bool? isProjectDelete, bool? isProjectZip}) async {
    if (appStore.screenList.length > 0) {
      createDartFile(0, true);
    }
  }


  Future<void> _saveCurrentScreenAsWidget() async {
    String? name = await showDialog<String>(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: Text('اسم الـ Widget'),
          content: TextField(
              controller: ctrl,
              decoration: InputDecoration(hintText: 'مثال: بطاقة منتج')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: Text('حفظ ومشاركة'),
            ),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      // جمع بيانات الشاشة الحالية
      Map<String, dynamic> rootScreenDataJson = await widgetClassToJsonData();
      final screenJson = jsonEncode(rootScreenDataJson);
      await saveUserWidgetApi({
        'name': name,
        'screen_data': screenJson,
        'is_community': 1,
      });
      getToast('تم مشاركة الـ Widget بنجاح! ✔');
    }
  }

  Map getDownloadFileRequest(bool isProjectDelete, bool isProjectZip,
      String fileName, String filesContent) {
    Map req = {
      "project_name": appStore.projectName.validate(),
      "is_project_delete": isProjectDelete,
      "is_project_zip": isProjectZip,
      "file_name": fileName,
      "file_content": filesContent,
    };
    return req;
  }

  downloadOtherFiles(int index, bool isDeleteProject) async {
    if (!isContainsExtraFiles(appStore.headerImport[index])) {
      bool isProjectZip = false;
      String fileName = appStore.headerImport[index]
          .replaceAll("import ", "")
          .replaceAll("'", "")
          .replaceAll(";", "");
      String fileContent = await loadFileContent(fileName);

      Map req = getDownloadFileRequest(
          isDeleteProject, isProjectZip, fileName, fileContent);

      await downloadProject(req).then((value) async {
        int newIndex = index + 1;
        if (appStore.headerImport.length > newIndex) {
          await downloadOtherFiles(newIndex, false);
        }
      }).catchError((e) {
        appStore.setProjectDownloading(false);
        getToast(e.toString());
      });
    }
  }

  /// Create a dart file on server for download
  createDartFile(int index, bool isDeleteProject) async {
    if (appStore.screenList[index].id! > 0) {
      appStore.setProjectDownloading(true);

      appStore.codeViewData.clear();
      appStore.headerImport.clear();
      appStore.yamlImportLib.clear();

      DownloadModel aDownloadModel = await applyScreenJsonToView(
          appStore.screenList[index].screenJsonData,
          isForDownload: true);
      aDownloadModel.fileName = appStore.screenList[index].name;
      List<String> filesContent = await viewFinalSourceData(
          aDownloadModel.selectedWidgetList,
          downloadModel: aDownloadModel);

      /// Other Files
      if (appStore.headerImport.length > 0) {
        await downloadOtherFiles(0, isDeleteProject);
      }

      String codeContent = "";

      for (int i = 0; i < filesContent.length; i++) {
        codeContent = codeContent + filesContent[i];
      }

      Map req = getDownloadFileRequest(
          isDeleteProject,
          (appStore.screenList.length - 1) == index ? true : false,
          "${getFileName(projectFileName: appStore.screenList[index].name)}.dart",
          codeContent);

      await downloadProject(req).then((value) {
        if (index == appStore.screenList.length - 1 && value.url!.isNotEmpty) {
          trackUserEvent(DOWNLOAD_PROJECT_CODE);
          appStore.setProjectDownloading(false);
          webFile.AnchorElement(
            href: value.url,
          )
            ..setAttribute("download", "${appStore.projectName}")
            ..click();
        } else {
          int newIndex = index + 1;
          if (appStore.screenList.length > newIndex) {
            createDartFile(newIndex, false);
          }
        }
      }).catchError((e) {
        appStore.setProjectDownloading(false);
        getToast(e.toString());
      });
    } else {
      int newIndex = index + 1;
      if (appStore.screenList.length > newIndex) {
        createDartFile(newIndex, (newIndex == 1) ? true : false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.scaffoldBackgroundColor),
        child: (appStore.selectedMenu == SCREEN_LIST_INDEX ||
                appStore.selectedMenu == WIDGETS_INDEX ||
                appStore.selectedMenu == TREE_INDEX ||
                appStore.selectedMenu == PRE_COMPONENTS_INDEX)
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  getHeaderLogoImage(),
                  16.width,
                  (appStore.screenTemplateData == null)
                      ? Row(
                          children: [
                            OnHover(builder: (isHovered) {
                              return elevationButtonHighLightColor(
                                isHovered: isHovered,
                                child:
                                    highLightIcon(isHovered, icon: Icons.add),
                                toolTipMessage: language!.createPage,
                                onPressed: () async {
                                  ifNotTester(() async {
                                    trackUserEvent(VIEW_TEMPLATES);
                                    await showInDialog(
                                      context,
                                      contentPadding: EdgeInsets.all(30),
                                      backgroundColor:
                                          context.scaffoldBackgroundColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            COMMON_CARD_BORDER_RADIUS),
                                      ),
                                      builder: (context) => AddPageDialog(),
                                    );
                                  });
                                },
                              );
                            }),
                            16.width,
                            OnHover(builder: (isHovered) {
                              return elevationButtonHighLightColor(
                                isHovered: isHovered,
                                child: highLightIcon(isHovered,
                                    icon: Icons.feedback),
                                toolTipMessage: language!.feedBack,
                                onPressed: () async {
                                  await showInDialog(
                                    context,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          COMMON_CARD_BORDER_RADIUS),
                                    ),
                                    contentPadding: EdgeInsets.all(16),
                                    builder: (context) => FeedbackDialog(),
                                  );
                                },
                              );
                            }),
                            16.width,
                            OnHover(builder: (isHovered) {
                              return Observer(
                                builder: (_) => elevationButtonHighLightColor(
                                  isHovered: isHovered,
                                  child: (appStore.isProjectDownloading)
                                      ? Container(
                                          width: 25,
                                          height: 25,
                                          child:
                                              Lottie.asset('images/loader.json')
                                                  .center(),
                                        ).visible(appStore.isProjectDownloading)
                                      : highLightIcon(isHovered,
                                          icon: Icons.download),
                                  toolTipMessage:
                                      (appStore.isProjectDownloading)
                                          ? language!.downloadingInProgress
                                          : language!.downloadProject,
                                  onPressed: () async {
                                    ifNotTester(() async {
                                      if (appStore.isProjectDownloading) {
                                        getToast(
                                            language!.downloadingInProgress);
                                      } else {
                                        downloadProjectLatest();
                                      }
                                    });
                                  },
                                ),
                              );
                            }),
                            16.width,

                            /// Build APK Button
                            OnHover(builder: (isHovered) {
                              return Observer(
                                builder: (_) => elevationButtonHighLightColor(
                                  isHovered: isHovered,
                                  child: (appStore.isApkBuilding)
                                      ? Container(
                                          width: 25,
                                          height: 25,
                                          child:
                                              Lottie.asset('images/loader.json')
                                                  .center(),
                                        ).visible(appStore.isApkBuilding)
                                      : highLightIcon(isHovered,
                                          icon: Icons.android),
                                  toolTipMessage: (appStore.isApkBuilding)
                                      ? 'جاري بناء APK...'
                                      : 'تصدير APK للهاتف',
                                  onPressed: () async {
                                    ifNotTester(() async {
                                      if (appStore.isApkBuilding) {
                                        getToast(
                                            'الرجاء الانتظار حتى يكتمل البناء الحالي');
                                      } else {
                                        buildProjectApkLatest();
                                      }
                                    });
                                  },
                                ),
                              );
                            }),
                            16.width,

                            /// Community Widgets Store Button
                            OnHover(builder: (isHovered) {
                              return elevationButtonHighLightColor(
                                isHovered: isHovered,
                                child:
                                    highLightIcon(isHovered, icon: Icons.store),
                                toolTipMessage: 'متجر الـ Widgets',
                                onPressed: () {
                                  CommunityWidgetsScreen().launch(context);
                                },
                              );
                            }),
                            16.width,

                            /// Community Widgets Share Button
                             OnHover(builder: (isHovered) {
                               return elevationButtonHighLightColor(
                                 isHovered: isHovered,
                                 child: highLightIcon(isHovered,
                                     icon: Icons.cloud_upload),
                                 toolTipMessage: 'مشاركة الشاشة كـ Widget',
                                 onPressed: () => _saveCurrentScreenAsWidget(),
                               );
                             }),
                             16.width,

                             /// AI Builder Button
                             OnHover(builder: (isHovered) {
                               return elevationButtonHighLightColor(
                                 isHovered: isHovered,
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                   decoration: BoxDecoration(
                                     gradient: const LinearGradient(
                                       colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                       begin: Alignment.centerLeft,
                                       end: Alignment.centerRight,
                                     ),
                                     borderRadius: BorderRadius.circular(8),
                                   ),
                                   child: const Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       Icon(Icons.auto_awesome, color: Colors.white, size: 15),
                                       SizedBox(width: 5),
                                       Text('AI', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                     ],
                                   ),
                                 ),
                                 toolTipMessage: 'AI App Builder',
                                 onPressed: () {
                                   showDialog(
                                     context: context,
                                     barrierColor: Colors.transparent,
                                     builder: (_) => Align(
                                       alignment: Alignment.centerRight,
                                       child: Material(
                                         color: Colors.transparent,
                                         child: AiChatScreen(
                                           projectId: appStore.projectId ?? 0,
                                           screenId: appStore.selectedScreenId,
                                         ),
                                       ),
                                     ),
                                   );
                                 },
                               );
                             }),
                             16.width,

                            /// Uploading Functionality
                            OnHover(builder: (isHovered) {
                              return Observer(
                                builder: (_) => elevationButtonHighLightColor(
                                  isHovered: isHovered,
                                  child: highLightIcon(isHovered,
                                      icon: Icons.upload),
                                  toolTipMessage: language!.uploadProjectFile,
                                  onPressed: () async {
                                    List<MediaRequestModel> imageUint8List = [];

                                    // final FilePickerResult? _filePicker = await FilePicker.platform.pickFiles(
                                    //   allowedExtensions: ['dart'],
                                    //   type: FileType.custom,
                                    // );

                                    // _filePicker!.files.forEach((element) async {
                                    //   imageUint8List.add(MediaRequestModel(file: element.bytes, fileName: element.name));
                                    //   String result = utf8.decode(element.bytes!);
                                    //   toast(result);
                                    // });
                                    appStore.setLoading(true);

                                    Future.delayed(Duration(seconds: 5), () {
                                      if (imageUint8List.isNotEmpty) {
                                        toast("File is Uploaded");
                                      }
                                    });
                                  },
                                ),
                              );
                            }),
                            16.width,

                                                         /// Backend Builder Button
                             OnHover(builder: (isHovered) {
                               return elevationButtonHighLightColor(
                                 isHovered: isHovered,
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                   decoration: BoxDecoration(
                                     gradient: const LinearGradient(
                                       colors: [Color(0xFF059669), Color(0xFF047857)],
                                       begin: Alignment.centerLeft,
                                       end: Alignment.centerRight,
                                     ),
                                     borderRadius: BorderRadius.circular(8),
                                   ),
                                   child: const Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       Icon(Icons.code_rounded, color: Colors.white, size: 15),
                                       SizedBox(width: 5),
                                       Text('Backend', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                     ],
                                   ),
                                 ),
                                 toolTipMessage: 'Backend Builder',
                                 onPressed: () {
                                   showDialog(
                                     context: context,
                                     barrierColor: Colors.transparent,
                                     builder: (_) => Align(
                                       alignment: Alignment.centerRight,
                                       child: Material(
                                         color: Colors.transparent,
                                         child: BackendChatScreen(
                                           projectId: appStore.projectId ?? 0,
                                         ),
                                       ),
                                     ),
                                   );
                                 },
                               );
                             }),
                             16.width,
                          ],
                        )
                      : SizedBox(),
                  (appStore.screenTemplateData != null)
                      ? Row(
                          children: [
                            OnHover(builder: (isHovered) {
                              return elevationButtonHighLightColor(
                                toolTipMessage: language!.viewSourceCode,
                                isHovered: isHovered,
                                child:
                                    highLightIcon(isHovered, icon: Icons.code),
                                onPressed: () {
                                  viewSourceCode(context);
                                },
                              );
                            }),
                            16.width,
                            OnHover(
                              builder: (isHovered) {
                                return elevationButtonHighLightColor(
                                  toolTipMessage:
                                      language!.clearCurrentScreenData,
                                  isHovered: isHovered,
                                  child: highLightIcon(isHovered,
                                      icon: Icons.clear_all),
                                  onPressed: () {
                                    showConfirmDialog(
                                      context,
                                      language!.areYouClearScreenData,
                                      onAccept: () {
                                        trackUserEvent(CLEAR_DATA);
                                        appStore.resetView();
                                      },
                                      buttonColor: appStore.isDarkMode
                                          ? darkModeHighLightColor
                                          : Colors.red,
                                      positiveText: language!.clear,
                                      negativeText: language!.cancel,
                                    );
                                  },
                                );
                              },
                            ),
                            16.width,
                          ],
                        )
                      : SizedBox(),
                  OnHover(
                    builder: (isHovered) {
                      return elevationButtonWithText(
                        isHovered: isHovered,
                        toolTipMessage: "My Projects",
                        image: 'project_white.svg',
                        title: "My Projects",
                        onPressed: () {
                          if (getStringAsync(USER_TYPE) == USER) {
                            appStore.isProjectDownloading = false;
                            WelcomeScreen().launch(getContext, isNewTask: true);
                          }
                        },
                      );
                    },
                  ),
                  16.width,
                  OnHover(builder: (isHovered) {
                    return elevationButtonWithIcon(
                      isHovered: isHovered,
                      toolTipMessage: language!.save,
                      icon: Icons.save,
                      title: appStore.isComponent
                          ? (appStore.screenTemplateData == null)
                              ? language!.save
                              : language!.saveComponent
                          : appStore.isProjectTemplate
                              ? (appStore.screenTemplateData == null)
                                  ? language!.save
                                  : language!.saveTemplateAsProject
                              : (appStore.screenTemplateData == null)
                                  ? language!.save
                                  : language!.saveTemplates,
                      onPressed: () async {
                        ifNotTester(() async {
                          if (appStore.isProjectDownloading) {
                            getToast(language!.downloadingInProgress);
                          } else {
                            Map<String, dynamic> rootScreenDataJson =
                                await widgetClassToJsonData();

                            if (appStore.screenTemplateData == null) {
                              if (appStore.selectedScreenId! > 0) {
                                saveScreenApi();
                              }
                            } else {
                              appStore.isComponent
                                  ? addComponentApi(rootScreenDataJson)
                                  : appStore.isProjectTemplate
                                      ? addProjectTemplateApi(
                                          rootScreenDataJson)
                                      : addTemplateApi(rootScreenDataJson);
                            }
                          }
                        });
                      },
                    );
                  }),
                  SizedBox(width: 16)
                      .visible(appStore.screenTemplateData == null),
                  (appStore.screenTemplateData == null)
                      ? OnHover(builder: (isHovered) {
                          return elevationButtonHighLightColor(
                            isHovered: isHovered,
                            child: SvgPicture.asset(
                              "${WidgetIconPath}preview.svg",
                              color: isHovered
                                  ? btnBackgroundColor
                                  : appStore.isDarkMode
                                      ? Colors.white
                                      : btnBackgroundColor,
                              height: btnIconSize,
                              width: btnIconSize,
                            ),
                            toolTipMessage: language!.preview,
                            onPressed: () async {
                              appStore.setPreviewCode(true);
                              PreviewScreen().launch(context);
                            },
                          );
                        })
                      : SizedBox(),
                  SizedBox(width: 16)
                      .visible(appStore.screenTemplateData != null),
                  (appStore.screenTemplateData != null)
                      ? OnHover(builder: (isHovered) {
                          return elevationButtonWithIcon(
                              isHovered: isHovered,
                              toolTipMessage: language!.back,
                              title: language!.back,
                              icon: Icons.arrow_back,
                              onPressed: () {
                                showConfirmDialog(
                                  context,
                                  language!.areYouWantToBack,
                                  buttonColor: appStore.isDarkMode
                                      ? darModePrimaryTextColor
                                      : textColorPrimary,
                                  onAccept: () {
                                    appStore.selectedMenu =
                                        ADMIN_TEMPLATES_INDEX;
                                    finish(context);
                                  },
                                );
                              });
                        })
                      : SizedBox(),
                  appStore.screenTemplateData == null ? 16.width : 0.width,
                  appStore.screenTemplateData == null
                      ? darkModeSwitchWidget()
                      : SizedBox(),
                  appStore.screenTemplateData == null ? 16.width : 0.width,
                  appStore.screenTemplateData == null
                      ? getProfileWidget(context)
                      : SizedBox(),
                ],
              )
            : Row(
                children: [
                  getHeaderLogoImage(),
                  16.width,
                  darkModeSwitchWidget(),
                  16.width,
                  getProfileWidget(context),
                ],
              ),
      );
    });
  }
}
