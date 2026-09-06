import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';
import '../store/ai_chat_store.dart';
import '../model/ai_chat_models.dart';
import '../network/ai_api_client.dart';
import '../utils/AppConstant.dart';

/// AiChatScreen — sliding AI chat panel overlay.
///
/// Usage: show as a side panel or bottom sheet over the editor.
/// Uses AiChatStore (MobX) for state management.
class AiChatScreen extends StatefulWidget {
  final int projectId;
  final int? screenId;

  const AiChatScreen({
    super.key,
    required this.projectId,
    this.screenId,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> with SingleTickerProviderStateMixin {
  late final AiChatStore _store;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  bool _showSidebar = false;

  @override
  void initState() {
    super.initState();
    _store = AiChatStore(projectId: widget.projectId, screenId: widget.screenId);
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    // Load existing conversation from backend; show welcome only if none found
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _store.loadOrCreateLastConversation();
      // Show welcome if this is a completely fresh conversation
      if (_store.messages.isEmpty) {
        _store.messages.add(AiChatMessage(
          id: 'welcome',
          role: AiMessageRole.assistant,
          content: '👋 Hi! I\'m your AI assistant.\n\nTell me what to build — for example:\n• "Add a blue button below the text"\n• "Create a login screen"\n• "Change the text color to red"',
          timestamp: DateTime.now(),
        ));
      }
    });
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
        child: Stack(
          children: [
            // ── Main chat column ──
            Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildMessageList()),
                Observer(builder: (_) {
                  if (_store.pendingConfirmMessage != null) {
                    return _buildConfirmBanner();
                  }
                  return const SizedBox.shrink();
                }),
                _buildInputBar(context),
              ],
            ),
            // ── Conversation sidebar (slides over the chat) ──
            Observer(builder: (_) {
              if (!_showSidebar) return const SizedBox.shrink();
              return _buildSidebar(context);
            }),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          // History sidebar toggle
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white70, size: 18),
            tooltip: 'Conversation history',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _showSidebar = !_showSidebar),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text(
            'AI Builder',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // New conversation button
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: Colors.white70, size: 18),
            tooltip: 'New conversation',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () async {
              await _store.createNewConversation();
              // Show welcome in fresh conversation
              if (_store.messages.isEmpty) {
                _store.messages.add(AiChatMessage(
                  id: 'welcome_new',
                  role: AiMessageRole.assistant,
                  content: '✨ New conversation started! What would you like to build?',
                  timestamp: DateTime.now(),
                ));
              }
            },
          ),
          const SizedBox(width: 4),
          // Close panel
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

  // ─────────────────────────────────────────────────────────
  // Message list
  // ─────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return Observer(builder: (_) {
      // Show spinner while loading history from backend
      if (_store.isLoadingHistory) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2),
              SizedBox(height: 12),
              Text('Loading conversation...', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      if (_store.messages.isEmpty) {
        return const Center(
          child: Text('Start a conversation...', style: TextStyle(color: Colors.grey)),
        );
      }

      return ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(12),
        itemCount: _store.messages.length,
        itemBuilder: (context, i) => _buildMessageBubble(_store.messages[i]),
      );
    });
  }

  Widget _buildMessageBubble(AiChatMessage msg) {
    final isUser    = msg.role == AiMessageRole.user;
    final isLoading = msg.isLoading;
    final isError   = msg.isError;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildAvatar(isError),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF4F46E5)
                    : isError
                        ? const Color(0xFF7F1D1D)
                        : const Color(0xFF252D40),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isError
                    ? Border.all(color: Colors.red.withValues(alpha: 0.3))
                    : null,
              ),
              child: isLoading
                  ? const _TypingIndicator()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                        // Plan preview for pending confirmation
                        if (msg.requiresConfirmation && msg.planPreview != null) ...[
                          const SizedBox(height: 8),
                          _buildPlanPreview(msg.planPreview!),
                        ],
                      ],
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildPlanPreview(String preview) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋 Plan:', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(preview, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isError) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isError
            ? const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF991B1B)])
            : const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
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

  // ─────────────────────────────────────────────────────────
  // Confirmation banner
  // ─────────────────────────────────────────────────────────

  Widget _buildConfirmBanner() {
    final pending = _store.pendingConfirmMessage!;
    final descriptors = pending.pendingDescriptors;
    final batchId = pending.batchId;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A4A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '⚡ Confirm Changes',
            style: TextStyle(color: Color(0xFFA78BFA), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${descriptors.length} action(s) will be applied to your project.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _store.cancelPlan,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: batchId != null
                      ? () => _store.confirmPlan(batchId, descriptors, context)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Observer(builder: (_) {
                    return _store.isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Apply', style: TextStyle(fontSize: 12, color: Colors.white));
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Input bar
  // ─────────────────────────────────────────────────────────

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
              textInputAction: TextInputAction.newline,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ask AI to build something...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF252D40),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
              ),
              onSubmitted: (v) {
                if (!v.trim().isEmpty) _sendMessage(context);
              },
            ),
          ),
          const SizedBox(width: 8),
          Observer(builder: (_) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _store.isLoading ? null : () => _sendMessage(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: _store.isLoading
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _store.isLoading ? const Color(0xFF374151) : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _store.isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _sendMessage(BuildContext context) {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    _store.sendMessage(text, context);
  }

  // ─────────────────────────────────────────────────────────
  // Conversation sidebar
  // ─────────────────────────────────────────────────────────

  Widget _buildSidebar(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Dim overlay — tap to close
          GestureDetector(
            onTap: () => setState(() => _showSidebar = false),
            child: Container(color: Colors.black54),
          ),
          // Sidebar panel
          Positioned(
            top: 0,
            left: 0,
            bottom: 0,
            width: 280,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF141824),
                border: Border(
                  right: BorderSide(color: Color(0xFF3D4A6B), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF252D40))),
                    ),
                    child: Row(
                      children: [
                        const Text('History',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        // New conversation button in sidebar
                        IconButton(
                          icon: const Icon(Icons.add, color: Color(0xFF4F46E5), size: 20),
                          tooltip: 'New conversation',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            setState(() => _showSidebar = false);
                            await _store.createNewConversation();
                            if (_store.messages.isEmpty) {
                              _store.messages.add(AiChatMessage(
                                id: 'welcome_new',
                                role: AiMessageRole.assistant,
                                content: '✨ New conversation started! What would you like to build?',
                                timestamp: DateTime.now(),
                              ));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  // ── Conversation list ──
                  Expanded(
                    child: Observer(builder: (_) {
                      if (_store.conversationList.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No conversations yet.',
                              style: TextStyle(color: Colors.white38, fontSize: 12)),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _store.conversationList.length,
                        itemBuilder: (ctx, i) {
                          final conv = _store.conversationList[i];
                          final convId = conv['id'] as int?;
                          final title = conv['title'] as String? ?? 'AI Session';
                          final isActive = convId == _store.conversationId;
                          return ListTile(
                            dense: true,
                            selected: isActive,
                            selectedColor: const Color(0xFF4F46E5),
                            selectedTileColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            leading: Icon(
                              Icons.chat_bubble_outline,
                              size: 16,
                              color: isActive ? const Color(0xFF4F46E5) : Colors.white38,
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Colors.white24),
                              tooltip: 'Delete',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: convId == null
                                  ? null
                                  : () async {
                                      final token = await getStringAsync(TOKEN);
                                      final ok = await AiApiClient.deleteConversation(
                                        conversationId: convId,
                                        token: token,
                                      );
                                      if (ok) {
                                        _store.removeConversationFromList(convId);
                                        if (_store.conversationList.isNotEmpty) {
                                          final next = _store.conversationList.first;
                                          await _store.switchConversation(next['id'] as int);
                                        } else {
                                          // Start fresh
                                          _store.messages.add(AiChatMessage(
                                            id: 'welcome_empty',
                                            role: AiMessageRole.assistant,
                                            content: '✨ Start a new conversation!',
                                            timestamp: DateTime.now(),
                                          ));
                                        }
                                      }
                                    },
                            ),
                            onTap: convId == null
                                ? null
                                : () async {
                                    setState(() => _showSidebar = false);
                                    await _store.switchConversation(convId);
                                  },
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing indicator
// ─────────────────────────────────────────────────────────────────────────────

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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
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
