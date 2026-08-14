import '../main.dart';

/// AiContextBuilder — extracts the Flutter-side UI context that the
/// backend ContextBuilder needs to understand the current state.
///
/// This context is sent with every /api/ai/chat request so the backend
/// can build the full picture without needing a separate roundtrip.
class AiContextBuilder {
  /// Build the payload fields that describe the Flutter editor state.
  ///
  /// These are merged into [AiChatRequest] before sending.
  static Map<String, dynamic> buildUiContext() {
    final store = appStore;

    final selectedWidget = store.currentSelectedWidget;
    final parentWidget  = store.currentParentWidget;

    // DEBUG: print to Flutter console
    print('[AI DEBUG] currentSelectedWidget: ${selectedWidget?.id} (${selectedWidget?.widgetType})');
    print('[AI DEBUG] currentParentWidget: ${parentWidget?.id}');

    return {
      if (selectedWidget != null) ...{
        'selected_widget_id':   selectedWidget.id,
        'selected_widget_type': selectedWidget.widgetSubType ?? selectedWidget.widgetType,
      },
      if (parentWidget != null)
        'current_parent_widget_id': parentWidget.id,
      'screen_id': store.selectedScreenId,
    };
  }

  /// Extract a flat index of all widgets in the current screen.
  /// Returns: [{id, type, label}]
  static List<Map<String, dynamic>> buildWidgetIndex() {
    final store = appStore;
    if (store.selectedWidgetList.isEmpty) return [];

    final index = <Map<String, dynamic>>[];
    _traverseWidget(store.selectedWidgetList[0], index);
    return index;
  }

  static void _traverseWidget(dynamic widget, List<Map<String, dynamic>> index) {
    if (widget == null) return;

    final id   = widget.id as String?;
    final type = widget.widgetSubType ?? widget.widgetType;

    if (id != null && type != null) {
      // Try to extract a display label from the widget's view model
      String? label;
      try {
        final vm = widget.widgetViewModel;
        label = vm?.text ?? vm?.title ?? vm?.hintText ?? vm?.labelText;
      } catch (_) {}

      index.add({'id': id, 'type': type, 'label': label});
    }

    final children = widget.subWidgetsList;
    if (children != null) {
      for (final child in children) {
        _traverseWidget(child, index);
      }
    }
  }
}
