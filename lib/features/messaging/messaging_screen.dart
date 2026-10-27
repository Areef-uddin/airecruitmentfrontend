import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../shared/widgets/top_navbar.dart';
import '../../shared/widgets/sidebar_navigation.dart';
import '../../shared/widgets/app_card.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/messaging_repository.dart';

class MessagingScreen extends ConsumerStatefulWidget {
  final int? initialContactUserId;
  const MessagingScreen({super.key, this.initialContactUserId});

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen> {
  final MessagingRepository _repo = MessagingRepository();
  List<ChatContact> _contacts = [];
  bool _isLoadingContacts = true;
  ChatContact? _activeContact;
  int? _activeConversationId;
  List<ChatMessageItem> _messages = [];
  bool _isLoadingMessages = false;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;

  // AI Auto Suggestions
  List<String> _aiSuggestions = [];
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_activeConversationId != null && mounted) {
        _pollMessages();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _fetchContacts() async {
    setState(() => _isLoadingContacts = true);
    final list = await _repo.getContacts();
    if (!mounted) return;
    setState(() {
      _contacts = list;
      _isLoadingContacts = false;
    });

    if (widget.initialContactUserId != null) {
      final matches = _contacts.where((c) => c.id == widget.initialContactUserId);
      if (matches.isNotEmpty) {
        _selectContact(matches.first);
        return;
      }
    }

    if (_contacts.isNotEmpty && _activeContact == null && ResponsiveLayout.isDesktop(context)) {
      _selectContact(_contacts.first);
    }
  }

  void _selectContact(ChatContact contact) async {
    setState(() {
      _activeContact = contact;
      _isLoadingMessages = true;
      _aiSuggestions = [];
    });

    try {
      final conv = await _repo.getOrCreateConversation(contact.id);
      final convId = conv['id'] as int;
      if (!mounted) return;
      setState(() => _activeConversationId = convId);
      final msgs = await _repo.getMessages(convId);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _isLoadingMessages = false;
      });
      _scrollToBottom();
      _fetchAiSuggestions();
    } catch (_) {
      if (mounted) setState(() => _isLoadingMessages = false);
    }
  }

  void _pollMessages() async {
    if (_activeConversationId == null) return;
    try {
      final msgs = await _repo.getMessages(_activeConversationId!);
      if (!mounted) return;
      if (msgs.length != _messages.length) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage({String? customText}) async {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty || _activeConversationId == null) return;

    _textController.clear();
    setState(() => _aiSuggestions.clear());

    try {
      final sent = await _repo.sendMessage(_activeConversationId!, text);
      if (!mounted) return;
      setState(() {
        _messages.add(sent);
      });
      _scrollToBottom();
    } catch (_) {}
  }

  void _fetchAiSuggestions() async {
    if (!mounted) return;
    setState(() => _isLoadingSuggestions = true);
    final lastText = _messages.isNotEmpty ? _messages.last.body : "Initial interview greeting";
    final suggestions = await _repo.getAiSuggestions(
      lastText,
      context: "Recruiting conversation with ${_activeContact?.name ?? 'candidate'}",
    );
    if (!mounted) return;
    setState(() {
      _aiSuggestions = suggestions;
      _isLoadingSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    // If mobile and in active conversation, show chat view with back button
    final showMobileChat = !isDesktop && _activeContact != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const TopNavbar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  SidebarNavigation(user: user, currentRoute: '/messages'),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(isDesktop ? 24 : 12),
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: Row(
                        children: [
                          // Left pane: Contacts list (hide on mobile when chat open)
                          if (isDesktop || !showMobileChat)
                            SizedBox(
                              width: isDesktop ? 340 : double.infinity,
                              child: _buildContactsPane(isDesktop),
                            ),

                          // Divider for desktop
                          if (isDesktop)
                            const VerticalDivider(color: AppColors.border, width: 1),

                          // Right pane: Active chat (hide on mobile when no contact selected)
                          if (isDesktop || showMobileChat)
                            Expanded(
                              child: _buildChatPane(isDesktop, showMobileChat),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsPane(bool isDesktop) {
    final user = ref.watch(authProvider).user;
    final isRecruiter = user?.isRecruiter ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRecruiter ? 'Candidates & Messages' : 'Direct Messages',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      isRecruiter ? 'Connect directly with applicants' : 'Chat with recruiters',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8), size: 18),
                tooltip: 'Refresh Contacts',
                onPressed: _fetchContacts,
              ),
            ],
          ),
        ),
        const Divider(color: AppColors.border, height: 1),

        // Contacts List
        Expanded(
          child: _isLoadingContacts
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _contacts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 40, color: Colors.white.withOpacity(0.25)),
                            const SizedBox(height: 12),
                            Text(
                              isRecruiter ? 'No candidates found yet' : 'No recruiters found yet',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isRecruiter
                                  ? 'Candidates will appear here as they register or apply.'
                                  : 'Explore jobs and apply to connect with recruiters.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _contacts.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E2030), height: 1),
                      itemBuilder: (ctx, idx) {
                        final c = _contacts[idx];
                        final isSelected = _activeContact?.id == c.id;

                        return InkWell(
                          onTap: () => _selectContact(c),
                          child: Container(
                            color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isSelected ? AppColors.primary : const Color(0xFF2E324D),
                                  child: Text(
                                    c.name.isNotEmpty ? c.name[0].toUpperCase() : 'U',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              c.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          if (c.unreadCount > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD946EF),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '${c.unreadCount}',
                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.headline,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildChatPane(bool isDesktop, bool showMobileChat) {
    final myUserId = ref.watch(authProvider).user?.id;

    if (_activeContact == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_chat_unread_outlined, size: 54, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 14),
            const Text(
              'Select a contact to start conversation',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Active Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF131522),
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Row(
            children: [
              if (showMobileChat)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => setState(() => _activeContact = null),
                ),
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primary,
                child: Text(
                  _activeContact!.name.isNotEmpty ? _activeContact!.name[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeContact!.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      _activeContact!.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  context.go('/live-interview?room=direct_${_activeContact!.id}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD946EF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.videocam, size: 15),
                label: Text(isDesktop ? 'Start Live Interview' : 'Meet', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Messages list
        Expanded(
          child: _isLoadingMessages
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 40, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 10),
                          const Text(
                            'No messages yet. Send a greeting to start chatting!',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: _messages.length,
                      itemBuilder: (ctx, idx) {
                        final m = _messages[idx];
                        final isMe = m.sender?['id'] == myUserId;

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (isDesktop ? 0.55 : 0.78)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primary : const Color(0xFF1E2133),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(14),
                                topRight: const Radius.circular(14),
                                bottomLeft: isMe ? const Radius.circular(14) : Radius.zero,
                                bottomRight: isMe ? Radius.zero : const Radius.circular(14),
                              ),
                              border: Border.all(
                                color: isMe ? AppColors.primary.withOpacity(0.5) : const Color(0xFF2E324D),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.body,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      m.createdAt.length >= 16 ? m.createdAt.substring(11, 16) : '',
                                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        m.isRead ? Icons.done_all : Icons.done,
                                        size: 13,
                                        color: m.isRead ? const Color(0xFF38BDF8) : Colors.white70,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),

        // AI Auto-Suggestions Bar (Gemini Powered)
        if (_aiSuggestions.isNotEmpty || _isLoadingSuggestions) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF10121C),
              border: Border(top: BorderSide(color: Color(0xFF222538))),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFD946EF), size: 15),
                const SizedBox(width: 8),
                const Text(
                  'AI Smart Replies:',
                  style: TextStyle(color: Color(0xFFD946EF), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _isLoadingSuggestions
                          ? [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(color: Color(0xFFD946EF), strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              const Text('Generating Gemini suggestions...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            ]
                          : _aiSuggestions.map((s) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  backgroundColor: const Color(0xFF1E2138),
                                  side: BorderSide(color: const Color(0xFFD946EF).withOpacity(0.35)),
                                  label: Text(
                                    s,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11),
                                  ),
                                  onPressed: () => _sendMessage(customText: s),
                                ),
                              );
                            }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF131522),
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.auto_awesome, color: Color(0xFFD946EF), size: 20),
                tooltip: 'Get AI Suggestions (Gemini)',
                onPressed: _fetchAiSuggestions,
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 22),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
