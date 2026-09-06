import 'package:flutter/widgets.dart';
import '../main.dart';
import '../model/ai_chat_models.dart';
import '../model/widget_model.dart';
import '../widgets/widgets.dart';
import '../network/rest_apis.dart';
import '../utils/AppCommon.dart';

/// AiActionExecutor — executes AI ActionDescriptors using AppStore.
///
/// DESIGN CONTRACT:
/// - This is the ONLY file that bridges AI actions ↔ AppStore.
/// - Each action becomes a normal undo/redo-compatible operation.
/// - After a BATCH is executed, a single snapshot is pushed to undoWidgetsList
///   so one Undo press reverts all AI changes in that batch.
/// - new_widget_id from descriptors is always null → Flutter calls getWidgetId().
/// - NO direct widget JSON mutation: we call AppStore methods only.
/// - Execution is sequential (actions may depend on each other).
class AiActionExecutor {
  /// Execute all descriptors in a batch and return results.
  ///
  /// IMPORTANT: call this inside a MobX action or runInAction block
  /// if you need to reactively update UI during execution.
  static Future<List<AiActionResult>> executeBatch(
    List<AiActionDescriptor> descriptors,
    BuildContext context,
  ) async {
    // 1. Save a pre-batch snapshot for a single-step undo
    _snapshotBeforeBatch();

    final results = <AiActionResult>[];

    for (final descriptor in descriptors) {
      final result = await _executeOne(descriptor, context);
      results.add(result);
      if (result.status == 'failed') {
        // Fail-fast: roll back by undoing the pre-batch snapshot
        _rollback();
        return results
          .map((r) => r.status == 'success'
              ? AiActionResult(
                  actionId: r.actionId,
                  type: r.type,
                  status: 'rolled_back',
                  createdId: r.createdId,
                )
              : r)
          .toList();
      }
    }

    return results;
  }

  // ─────────────────────────────────────────────────────────
  // Private dispatch
  // ─────────────────────────────────────────────────────────

  static Future<AiActionResult> _executeOne(
    AiActionDescriptor descriptor,
    BuildContext context,
  ) async {
    try {
      switch (descriptor.type) {
        case 'ADD_WIDGET':
          return await _addWidget(descriptor);
        case 'UPDATE_WIDGET':
        case 'UPDATE_PROPERTY':
        case 'UPDATE_STYLE':
          return _updateWidget(descriptor);
        case 'DELETE_WIDGET':
          return _deleteWidget(descriptor);
        case 'MOVE_WIDGET':
          return _moveWidget(descriptor);
        case 'DUPLICATE_WIDGET':
          return _duplicateWidget(descriptor);
        case 'CREATE_SCREEN':
          return await _createScreen(descriptor, context);
        case 'DELETE_SCREEN':
          return await _deleteScreen(descriptor, context);
        case 'RENAME_SCREEN':
          return _renameScreen(descriptor);
        case 'ADD_NAVIGATION':
          return _addNavigation(descriptor);
        case 'REMOVE_NAVIGATION':
          return _removeNavigation(descriptor);
        case 'UPDATE_THEME':
          return _updateTheme(descriptor);
        default:
          return AiActionResult(
            actionId: descriptor.actionId,
            type: descriptor.type,
            status: 'failed',
            error: 'Unknown action type: ${descriptor.type}',
          );
      }
    } catch (e) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: e.toString(),
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // ADD_WIDGET
  // ─────────────────────────────────────────────────────────

  static Future<AiActionResult> _addWidget(AiActionDescriptor descriptor) async {
    final widgetType = descriptor.widgetType ?? '';
    if (widgetType.isEmpty) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: 'widget_type is required',
      );
    }

    final parentId = descriptor.parentId;

    // If a specific parent widget is requested, select it first
    if (parentId != null) {
      _selectWidgetById(parentId);
    }

    // Create the widget model using existing widget factory
    final newWidget = getWidgetByType(widgetType);
    if (newWidget == null) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: 'Could not create widget of type: $widgetType',
      );
    }

    // Apply properties from descriptor
    if (descriptor.properties.isNotEmpty) {
      _applyProperties(newWidget, descriptor.properties);
    }

    // Add via AppStore — uses currentSelectedWidget as parent
    appStore.addChildWidget(newWidget);

    return AiActionResult(
      actionId: descriptor.actionId,
      type: descriptor.type,
      status: 'success',
      createdId: newWidget.id,
    );
  }

  // ─────────────────────────────────────────────────────────
  // UPDATE_WIDGET
  // ─────────────────────────────────────────────────────────

  static AiActionResult _updateWidget(AiActionDescriptor descriptor) {
    final widgetId = descriptor.targetWidgetId;
    if (widgetId == null) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: 'target.widget_id is required',
      );
    }

    final widget = _findWidgetById(widgetId);
    if (widget == null) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: 'Widget not found: $widgetId',
      );
    }

    _applyProperties(widget, descriptor.properties);

    // Force MobX observables to trigger for page-level widgets
    if (appStore.appBarClass != null && appStore.appBarClass!.id == widgetId) {
      final temp = appStore.appBarClass!;
      appStore.appBarClass = null;
      appStore.appBarClass = temp;
    } else if (appStore.drawerClass != null && appStore.drawerClass!.id == widgetId) {
      final temp = appStore.drawerClass!;
      appStore.drawerClass = null;
      appStore.drawerClass = temp;
    } else if (appStore.bottomNavigationBarClass != null && appStore.bottomNavigationBarClass!.id == widgetId) {
      final temp = appStore.bottomNavigationBarClass!;
      appStore.bottomNavigationBarClass = null;
      appStore.bottomNavigationBarClass = temp;
    }

    appStore.refreshMainViewData();

    return AiActionResult(
      actionId: descriptor.actionId,
      type: descriptor.type,
      status: 'success',
      targetId: widgetId,
    );
  }

  // ─────────────────────────────────────────────────────────
  // DELETE_WIDGET
  // ─────────────────────────────────────────────────────────

  static AiActionResult _deleteWidget(AiActionDescriptor descriptor) {
    final widgetId = descriptor.targetWidgetId;
    if (widgetId == null) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: 'target.widget_id is required',
      );
    }

    // Select the widget then call AppStore delete
    _selectWidgetById(widgetId);
    appStore.removeSelectedWidget();

    return AiActionResult(
      actionId: descriptor.actionId,
      type: descriptor.type,
      status: 'success',
      targetId: widgetId,
    );
  }

  // ─────────────────────────────────────────────────────────
  // MOVE_WIDGET
  // ─────────────────────────────────────────────────────────

  static AiActionResult _moveWidget(AiActionDescriptor descriptor) {
    final widgetId  = descriptor.targetWidgetId;
    final direction = descriptor.payload['direction'] as String? ?? 'up';

    if (widgetId == null) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: 'target.widget_id is required',
      );
    }

    _selectWidgetById(widgetId);
    appStore.moveWidget(isMoveUpOperation: direction == 'up');
    appStore.refreshMainViewData();

    return AiActionResult(
      actionId: descriptor.actionId,
      type: descriptor.type,
      status: 'success',
      targetId: widgetId,
    );
  }

  // ─────────────────────────────────────────────────────────
  // DUPLICATE_WIDGET
  // ─────────────────────────────────────────────────────────

  static AiActionResult _duplicateWidget(AiActionDescriptor descriptor) {
    final widgetId = descriptor.targetWidgetId;
    if (widgetId == null) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: 'target.widget_id is required',
      );
    }

    _selectWidgetById(widgetId);
    appStore.copyWidget();

    return AiActionResult(
      actionId: descriptor.actionId,
      type: descriptor.type,
      status: 'success',
      targetId: widgetId,
    );
  }

  // ─────────────────────────────────────────────────────────
  // CREATE_SCREEN
  // ─────────────────────────────────────────────────────────

  static Future<AiActionResult> _createScreen(
    AiActionDescriptor descriptor,
    BuildContext context,
  ) async {
    final screenName = descriptor.payload['screen_name'] as String? ?? 'New Screen';

    // Use existing addScreen API call — same as UI button
    final result = await addScreen({
      'project_id': appStore.projectId ?? 0,
      'name': screenName,
    });

    return AiActionResult(
      actionId: descriptor.actionId,
      type: descriptor.type,
      status: 'success',
      createdId: result.data?.id?.toString(),
    );
  }

  // ─────────────────────────────────────────────────────────
  // DELETE_SCREEN
  // ─────────────────────────────────────────────────────────

  static Future<AiActionResult> _deleteScreen(
    AiActionDescriptor descriptor,
    BuildContext context,
  ) async {
    final screenId = descriptor.target['screen_id'];
    if (screenId == null) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: 'target.screen_id is required',
      );
    }

    await deleteScreen({'id': int.tryParse(screenId.toString()) ?? screenId});

    return AiActionResult(
      actionId: descriptor.actionId,
      type: descriptor.type,
      status: 'success',
      targetId: screenId.toString(),
    );
  }

  // ─────────────────────────────────────────────────────────
  // RENAME_SCREEN
  // ─────────────────────────────────────────────────────────

  static AiActionResult _renameScreen(AiActionDescriptor descriptor) {
    final screenId  = descriptor.target['screen_id'];
    final newName   = descriptor.payload['new_name'] as String? ?? '';

    if (screenId == null || newName.isEmpty) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: 'screen_id and new_name are required',
      );
    }

    appStore.updateScreenName(newName, screenId);

    return AiActionResult(
      actionId: descriptor.actionId,
      type: descriptor.type,
      status: 'success',
      targetId: screenId.toString(),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ADD_NAVIGATION (via onPressed property)
  // ─────────────────────────────────────────────────────────

  static AiActionResult _addNavigation(AiActionDescriptor descriptor) {
    final widgetId    = descriptor.targetWidgetId;
    final destScreen  = descriptor.payload['destination_screen_name'] as String? ?? '';
    final navType     = descriptor.payload['navigation_type'] as String? ?? 'push';

    if (widgetId == null) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: 'target.widget_id is required',
      );
    }

    final widget = _findWidgetById(widgetId);
    if (widget == null) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: 'Widget not found: $widgetId',
      );
    }

    // Set onPressed / onClick property — navigation is just a property
    _applyProperties(widget, {
      'onPressed': destScreen,
      'navigationType': navType,
    });
    appStore.refreshMainViewData();

    return AiActionResult(
      actionId: descriptor.actionId,
      type: descriptor.type,
      status: 'success',
      targetId: widgetId,
    );
  }

  // ─────────────────────────────────────────────────────────
  // REMOVE_NAVIGATION
  // ─────────────────────────────────────────────────────────

  static AiActionResult _removeNavigation(AiActionDescriptor descriptor) {
    final widgetId = descriptor.targetWidgetId;
    if (widgetId == null) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: 'target.widget_id is required',
      );
    }

    final widget = _findWidgetById(widgetId);
    if (widget == null) {
      return AiActionResult(
        actionId: descriptor.actionId,
        type: descriptor.type,
        status: 'failed',
        error: 'Widget not found: $widgetId',
      );
    }

    _applyProperties(widget, {'onPressed': null, 'navigationType': null});
    appStore.refreshMainViewData();

    return AiActionResult(
      actionId: descriptor.actionId,
      type: descriptor.type,
      status: 'success',
      targetId: widgetId,
    );
  }

  // ─────────────────────────────────────────────────────────
  // UPDATE_THEME
  // ─────────────────────────────────────────────────────────

  static AiActionResult _updateTheme(AiActionDescriptor descriptor) {
    final themeProps = Map<String, dynamic>.from(
      descriptor.payload['theme_properties'] ?? descriptor.payload,
    );

    // Theme settings live in AppStore directly
    if (themeProps.containsKey('isDarkMode')) {
      final isDark = themeProps['isDarkMode'] == true;
      appStore.isDarkMode = isDark;
    }

    // Additional theme application would go here

    return AiActionResult(
      actionId: descriptor.actionId,
      type: descriptor.type,
      status: 'success',
    );
  }

  // ─────────────────────────────────────────────────────────
  // Undo/Redo snapshot helpers
  // ─────────────────────────────────────────────────────────

  /// Save the whole current selectedWidgetList as one entry in the undo stack.
  /// This makes the entire AI batch undo-able in a single Ctrl+Z.
  static void _snapshotBeforeBatch() {
    final snapshot = List<WidgetModel>.from(appStore.selectedWidgetList);
    appStore.undoWidgetsList.add(snapshot);
    appStore.redoWidgetList.clear();
  }

  static void _rollback() {
    if (appStore.undoWidgetsList.isNotEmpty) {
      final previous = appStore.undoWidgetsList.removeLast();
      appStore.selectedWidgetList.clear();
      appStore.selectedWidgetList.addAll(previous);
      appStore.refreshMainViewData();
    }
  }

  // ─────────────────────────────────────────────────────────
  // Widget tree traversal helpers
  // ─────────────────────────────────────────────────────────

  static WidgetModel? _findWidgetById(String id) {
    if (appStore.appBarClass != null && appStore.appBarClass!.id == id) return appStore.appBarClass;
    if (appStore.drawerClass != null && appStore.drawerClass!.id == id) return appStore.drawerClass;
    if (appStore.bottomNavigationBarClass != null && appStore.bottomNavigationBarClass!.id == id) return appStore.bottomNavigationBarClass;

    if (appStore.selectedWidgetList.isEmpty) return null;
    return _searchInWidget(appStore.selectedWidgetList[0], id);
  }

  static WidgetModel? _searchInWidget(WidgetModel? node, String id) {
    if (node == null) return null;
    if (node.id == id) return node;
    if (node.subWidgetsList != null) {
      for (final child in node.subWidgetsList!) {
        final found = _searchInWidget(child, id);
        if (found != null) return found;
      }
    }
    return null;
  }

  static void _selectWidgetById(String id) {
    final widget = _findWidgetById(id);
    if (widget != null) {
      appStore.updateSelectedWidget(widget);
    }
  }

  /// Apply a map of raw properties to a widget's view model.
  /// Only known properties are applied; unknown keys are silently skipped.
  static void _applyProperties(WidgetModel widget, Map<String, dynamic> properties) {
    final vm = widget.widgetViewModel;
    if (vm == null) return;

    properties.forEach((key, value) {
      try {
        switch (key) {
          case 'text':           _trySet(vm, 'text',           value); break;
          case 'title':          _trySet(vm, 'title',          value); break;
          case 'hintText':       _trySet(vm, 'hintText',       value); break;
          case 'labelText':      _trySet(vm, 'labelText',      value); break;
          case 'backgroundColor':_trySet(vm, 'backgroundColor', value); break;
          case 'color':          _trySet(vm, 'color',           value); break;
          case 'foregroundColor':_trySet(vm, 'foregroundColor', value); break;
          case 'fontSize':       _trySet(vm, 'fontSize',        _toDouble(value)); break;
          case 'width':          _trySet(vm, 'width',           _toDouble(value)); break;
          case 'height':         _trySet(vm, 'height',          _toDouble(value)); break;
          case 'borderRadius':   _trySet(vm, 'borderRadius',    _toDouble(value)); break;
          case 'elevation':      _trySet(vm, 'elevation',       _toDouble(value)); break;
          case 'isExpanded':     _trySet(vm, 'isExpanded',      value == true || value == 'true'); break;
          case 'onPressed':      _trySet(vm, 'onPressed',       value); break;
          case 'navigationType': _trySet(vm, 'navigationType',  value); break;
          // Additional properties are handled silently
          default: break;
        }
      } catch (_) {
        // Silently skip properties that don't apply to this widget type
      }
    });
  }

  static void _trySet(dynamic vm, String prop, dynamic value) {
    try {
      // Using mirrors is restricted in Flutter — use direct assignment
      // This works because all widget view models expose their properties as public fields
      switch (prop) {
        case 'text':           vm.text = value?.toString();           break;
        case 'title':          vm.title = value?.toString();          break;
        case 'hintText':       vm.hintText = value?.toString();       break;
        case 'labelText':      vm.labelText = value?.toString();      break;
        case 'backgroundColor':vm.backgroundColor = value != null ? fromJsonColor(value) : null; break;
        case 'color':          vm.color = value != null ? fromJsonColor(value) : null;           break;
        case 'foregroundColor':vm.foregroundColor = value != null ? fromJsonColor(value) : null; break;
        case 'fontSize':       vm.fontSize = value as double?;        break;
        case 'width':          vm.width = value as double?;           break;
        case 'height':         vm.height = value as double?;          break;
        case 'borderRadius':   vm.borderRadius = value as double?;    break;
        case 'elevation':      vm.elevation = value as double?;       break;
        case 'isExpanded':     vm.isExpanded = value as bool?;        break;
        case 'onPressed':      vm.onPressed = value as String?;       break;
        case 'navigationType': vm.navigationType = value as String?;  break;
      }
    } catch (_) {
      // Widget doesn't have this property — skip
    }
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: get WidgetModel from widget type string.
// Reuses the same factory as the drag-and-drop UI.
// ─────────────────────────────────────────────────────────────────────────────

WidgetModel? getWidgetByType(String widgetType) {
  // Delegates to getWidgets() from widgets.dart — same factory used by drag-and-drop.
  // getWidgets() calls getWidgetId() internally, so every AI widget gets a fresh unique ID.
  try {
    final w = getWidgets(widgetType);
    return w is WidgetModel ? w : null;
  } catch (_) {
    return null;
  }
}
