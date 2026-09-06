import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../model/backend_chat_models.dart';
import '../network/backend_api_client.dart';
import '../utils/AppConstant.dart';

class BackendChatScreen extends StatefulWidget {
  final int projectId;

  const BackendChatScreen({super.key, required this.projectId});

  @override
  State<BackendChatScreen> createState() => _BackendChatScreenState();
}

class _BackendChatScreenState extends State<BackendChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  final List<BackendChatMessage> _messages = [];
  bool _isLoading = false;
  int? _conversationId;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    // Welcome message
    _messages.add(BackendChatMessage(
      id: 'welcome',
      role: BackendMessageRole.assistant,
      content:
          '⚙️ مرحباً! أنا مساعد إنشاء الباك اند.\n\n'
          'أخبرني ماذا تريد بناؤه، مثلاً:\n'
          '• "أنشئ API لإدارة المستخدمين"\n'
          '• "أضف نظام تسجيل دخول مع JWT"\n'
          '• "أنشئ CRUD لجدول المنتجات"',
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        width: 360,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1F2E)
              : const Color(0xFFF5F7FF),
          border: const Border(
            left: BorderSide(color: Color(0xFF3D4A6B), width: 1),
          ),
        ),
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildMessageList()),
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF047857)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.code_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Backend Builder',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // New conversation
          IconButton(
            icon: const Icon(Icons.add_comment_outlined,
                color: Colors.white70, size: 18),
            tooltip: 'محادثة جديدة',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _startNewConversation,
          ),
          const SizedBox(width: 4),
          // Close
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ─── Message list ─────────────────────────────────────────

  Widget _buildMessageList() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(BackendChatMessage msg) {
    final isUser = msg.role == BackendMessageRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildAiAvatar(msg.isError),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF059669)
                        : msg.isError
                            ? const Color(0xFF7F1D1D)
                            : const Color(0xFF252D40),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: msg.isLoading
                      ? const _TypingIndicator()
                      : Text(
                          msg.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                ),
                // عرض الملفات المُولَّدة
                if (msg.generatedFiles.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildGeneratedFilesCard(msg.generatedFiles),
                ],
                // عرض أسئلة التوضيح
                if (msg.questions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildQuestionsCard(msg.questions),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildGeneratedFilesCard(List<Map<String, dynamic>> files) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open_rounded,
                  color: Color(0xFF34D399), size: 14),
              const SizedBox(width: 6),
              Text(
                '${files.length} ملف تم توليده',
                style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...files.map((f) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  children: [
                    Icon(
                      f['action'] == 'created'
                          ? Icons.add_circle_outline
                          : Icons.edit_outlined,
                      color: Colors.white54,
                      size: 12,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f['path'] as String? ?? '',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildQuestionsCard(List<String> questions) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A4A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF059669).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('❓ أسئلة للتوضيح:',
              style: TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...questions.map((q) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $q',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              )),
        ],
      ),
    );
  }

  Widget _buildAiAvatar(bool isError) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isError
            ? const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFF991B1B)])
            : const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF047857)]),
      ),
      child: const Icon(Icons.code_rounded, color: Colors.white, size: 14),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF374151),
      ),
      child: const Icon(Icons.person, color: Colors.white70, size: 16),
    );
  }

  // ─── Input bar ────────────────────────────────────────────

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2D3554), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'اطلب من AI إنشاء باك اند...',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF252D40),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF059669), width: 1.5),
                ),
              ),
              onSubmitted: (_) {
                if (!_isLoading) _sendMessage();
              },
            ),
          ),
          const SizedBox(width: 8),
          StatefulBuilder(builder: (context, setInner) {
            return GestureDetector(
              onTap: _isLoading ? null : _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: _isLoading
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF047857)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: _isLoading ? const Color(0xFF374151) : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white70),
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isLoading) return;
    _inputCtrl.clear();

    setState(() {
      _messages.add(BackendChatMessage.userMessage(text));
      _messages.add(BackendChatMessage.loading());
      _isLoading = true;
    });

    try {
      final token = await getStringAsync(TOKEN);
      final request = BackendGenerateRequest(
        projectId: widget.projectId,
        message: text,
        conversationId: _conversationId,
      );

      final response =
          await BackendApiClient.generate(request: request, token: token);

      setState(() {
        _messages.removeWhere((m) => m.isLoading);
        _isLoading = false;

        if (response.conversationId != null) {
          _conversationId = response.conversationId;
        }

        if (response.isSuccess) {
          final summary = response.analysis != null
              ? '✅ تم التوليد بنجاح!\n\n📊 التحليل:\n${response.analysis}'
              : '✅ تم توليد الملفات بنجاح!';
          _messages.add(BackendChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: BackendMessageRole.assistant,
            content: summary,
            timestamp: DateTime.now(),
            generatedFiles: response.generatedFiles,
          ));
        } else if (response.needsClarification) {
          _messages.add(BackendChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: BackendMessageRole.assistant,
            content:
                response.message ?? 'أحتاج بعض التوضيحات قبل المتابعة:',
            timestamp: DateTime.now(),
            questions: response.questions,
          ));
        } else {
          _messages.add(BackendChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: BackendMessageRole.assistant,
            content: '❌ خطأ: ${response.message ?? 'حدث خطأ غير متوقع.'}',
            timestamp: DateTime.now(),
            isError: true,
          ));
        }
      });
    } catch (e) {
      setState(() {
        _messages.removeWhere((m) => m.isLoading);
        _isLoading = false;
        _messages.add(BackendChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: BackendMessageRole.assistant,
          content: 'حدث خطأ في الاتصال: ${e.toString()}',
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
    }
  }

  void _startNewConversation() {
    setState(() {
      _conversationId = null;
      _messages.clear();
      _messages.add(BackendChatMessage(
        id: 'welcome_new',
        role: BackendMessageRole.assistant,
        content: '✨ محادثة جديدة! بماذا تريد إنشاء الباك اند؟',
        timestamp: DateTime.now(),
      ));
    });
  }
}

// ─── Typing Indicator ─────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final opacity = ((_ctrl.value + delay) % 1.0 < 0.5) ? 1.0 : 0.3;
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}