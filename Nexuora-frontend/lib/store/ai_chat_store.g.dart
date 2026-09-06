// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_chat_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AiChatStore on _AiChatStoreBase, Store {
  late final _$conversationIdAtom =
      Atom(name: '_AiChatStoreBase.conversationId', context: context);

  @override
  int? get conversationId {
    _$conversationIdAtom.reportRead();
    return super.conversationId;
  }

  @override
  set conversationId(int? value) {
    _$conversationIdAtom.reportWrite(value, super.conversationId, () {
      super.conversationId = value;
    });
  }

  late final _$messagesAtom =
      Atom(name: '_AiChatStoreBase.messages', context: context);

  @override
  ObservableList<AiChatMessage> get messages {
    _$messagesAtom.reportRead();
    return super.messages;
  }

  @override
  set messages(ObservableList<AiChatMessage> value) {
    _$messagesAtom.reportWrite(value, super.messages, () {
      super.messages = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_AiChatStoreBase.isLoading', context: context);

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$isLoadingHistoryAtom =
      Atom(name: '_AiChatStoreBase.isLoadingHistory', context: context);

  @override
  bool get isLoadingHistory {
    _$isLoadingHistoryAtom.reportRead();
    return super.isLoadingHistory;
  }

  @override
  set isLoadingHistory(bool value) {
    _$isLoadingHistoryAtom.reportWrite(value, super.isLoadingHistory, () {
      super.isLoadingHistory = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_AiChatStoreBase.errorMessage', context: context);

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$pendingConfirmMessageAtom =
      Atom(name: '_AiChatStoreBase.pendingConfirmMessage', context: context);

  @override
  AiChatMessage? get pendingConfirmMessage {
    _$pendingConfirmMessageAtom.reportRead();
    return super.pendingConfirmMessage;
  }

  @override
  set pendingConfirmMessage(AiChatMessage? value) {
    _$pendingConfirmMessageAtom.reportWrite(value, super.pendingConfirmMessage,
        () {
      super.pendingConfirmMessage = value;
    });
  }

  late final _$conversationListAtom =
      Atom(name: '_AiChatStoreBase.conversationList', context: context);

  @override
  ObservableList<Map<String, dynamic>> get conversationList {
    _$conversationListAtom.reportRead();
    return super.conversationList;
  }

  @override
  set conversationList(ObservableList<Map<String, dynamic>> value) {
    _$conversationListAtom.reportWrite(value, super.conversationList, () {
      super.conversationList = value;
    });
  }

  late final _$loadOrCreateLastConversationAsyncAction = AsyncAction(
      '_AiChatStoreBase.loadOrCreateLastConversation',
      context: context);

  @override
  Future<void> loadOrCreateLastConversation() {
    return _$loadOrCreateLastConversationAsyncAction
        .run(() => super.loadOrCreateLastConversation());
  }

  late final _$loadConversationAsyncAction =
      AsyncAction('_AiChatStoreBase.loadConversation', context: context);

  @override
  Future<void> loadConversation(int convId, {String? token}) {
    return _$loadConversationAsyncAction
        .run(() => super.loadConversation(convId, token: token));
  }

  late final _$createNewConversationAsyncAction =
      AsyncAction('_AiChatStoreBase.createNewConversation', context: context);

  @override
  Future<void> createNewConversation() {
    return _$createNewConversationAsyncAction
        .run(() => super.createNewConversation());
  }

  late final _$switchConversationAsyncAction =
      AsyncAction('_AiChatStoreBase.switchConversation', context: context);

  @override
  Future<void> switchConversation(int convId) {
    return _$switchConversationAsyncAction
        .run(() => super.switchConversation(convId));
  }

  late final _$sendMessageAsyncAction =
      AsyncAction('_AiChatStoreBase.sendMessage', context: context);

  @override
  Future<void> sendMessage(String text, BuildContext context) {
    return _$sendMessageAsyncAction.run(() => super.sendMessage(text, context));
  }

  late final _$confirmPlanAsyncAction =
      AsyncAction('_AiChatStoreBase.confirmPlan', context: context);

  @override
  Future<void> confirmPlan(int batchId,
      List<AiActionDescriptor> pendingDescriptors, BuildContext context) {
    return _$confirmPlanAsyncAction
        .run(() => super.confirmPlan(batchId, pendingDescriptors, context));
  }

  late final _$_AiChatStoreBaseActionController =
      ActionController(name: '_AiChatStoreBase', context: context);

  @override
  void removeConversationFromList(int convId) {
    final _$actionInfo = _$_AiChatStoreBaseActionController.startAction(
        name: '_AiChatStoreBase.removeConversationFromList');
    try {
      return super.removeConversationFromList(convId);
    } finally {
      _$_AiChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void cancelPlan() {
    final _$actionInfo = _$_AiChatStoreBaseActionController.startAction(
        name: '_AiChatStoreBase.cancelPlan');
    try {
      return super.cancelPlan();
    } finally {
      _$_AiChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearMessages() {
    final _$actionInfo = _$_AiChatStoreBaseActionController.startAction(
        name: '_AiChatStoreBase.clearMessages');
    try {
      return super.clearMessages();
    } finally {
      _$_AiChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
conversationId: ${conversationId},
messages: ${messages},
isLoading: ${isLoading},
isLoadingHistory: ${isLoadingHistory},
errorMessage: ${errorMessage},
pendingConfirmMessage: ${pendingConfirmMessage},
conversationList: ${conversationList}
    ''';
  }
}
