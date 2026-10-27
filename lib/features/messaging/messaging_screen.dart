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

enum ChatTab { direct, groups }

class MessagingScreen extends ConsumerStatefulWidget {
  final int? initialContactUserId;
  const MessagingScreen({super.key, this.initialContactUserId});

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen> {
  final MessagingRepository _repo = MessagingRepository();

  ChatTab _selectedTab = ChatTab.direct;

  // Direct chat state
  List<ChatContact> _contacts = [];
  bool _isLoadingContacts = true;
  ChatContact? _activeContact;
  int? _activeConversationId;
  List<ChatMessageItem> _messages = [];
  bool _isLoadingMessages = false;

  // Meeting Group chat state
  List<Map<String, dynamic>> _meetingGroups = [];
  bool _isLoadingGroups = true;
  Map<String, dynamic>? _activeGroup;
  List<Map<String, dynamic>> _groupMessages = [];

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
    _fetchMeetingGroups();

    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      if (_selectedTab == ChatTab.direct && _activeConversationId != null) {
        _pollMessages();
      } else if (_selectedTab == ChatTab.groups && _activeGroup != null) {
        _pollGroupMessages();
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

  Future<void> _fetchContacts() async {
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

    if (_contacts.isNotEmpty && _activeContact == null && _selectedTab == ChatTab.direct && ResponsiveLayout.isDesktop(context)) {
      _selectContact(_contacts.first);
    }
  }

  Future<void> _fetchMeetingGroups() async {
    setState(() => _isLoadingGroups = true);
    final list = await _repo.getMeetingGroups();
    if (!mounted) return;
    setState(() {
      _meetingGroups = list;
      _isLoadingGroups = false;
    });

    if (_selectedTab == ChatTab.groups && _meetingGroups.isNotEmpty && _activeGroup == null && ResponsiveLayout.isDesktop(context)) {
      _selectGroup(_meetingGroups.first);
    }
  }

  void _selectContact(ChatContact contact) async {
    setState(() {
      _activeContact = contact;
      _activeGroup = null;
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

  void _selectGroup(Map<String, dynamic> group) {
    setState(() {
      _activeGroup = group;
      _activeContact = null;
      final rawMsgs = (group['messages'] ?? group['chat_history'] as List? ?? []);
      _groupMessages = rawMsgs.cast<Map<String, dynamic>>();
      _aiSuggestions = [];
    });
    _scrollToBottom();
    _fetchGroupAiSuggestions();
  }

  Future<void> _pollMessages() async {
    if (_activeConversationId == null) return;
    final msgs = await _repo.getMessages(_activeConversationId!);
    if (!mounted) return;
    final existingIds = _messages.map((m) => m.id).toSet();
    if (msgs.length != _messages.length || msgs.any((m) => !existingIds.contains(m.id))) {
      setState(() => _messages = msgs);
      _scrollToBottom();
    }
  }

  Future<void> _pollGroupMessages() async {
    if (_activeGroup == null) return;
    final list = await _repo.getMeetingGroups();
    if (!mounted) return;
    final match = list.firstWhere(
      (g) => g['id'] == _activeGroup!['id'],
      orElse: () => _activeGroup!,
    );
    final rawMsgs = (match['messages'] ?? match['chat_history'] as List? ?? []);
    final updatedMsgs = rawMsgs.cast<Map<String, dynamic>>();
    if (updatedMsgs.length != _groupMessages.length) {
      setState(() {
        _activeGroup = match;
        _groupMessages = updatedMsgs;
      });
      _scrollToBottom();
    }
  }

  void _sendMessage({String? customText}) async {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty) return;
    _textController.clear();

    if (_selectedTab == ChatTab.direct && _activeConversationId != null) {
      final tempId = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _messages.add(ChatMessageItem(
          id: tempId,
          conversationId: _activeConversationId!,
          body: text,
          isRead: false,
          createdAt: DateTime.now().toIso8601String(),
          sender: {'id': ref.read(authProvider).user?.id, 'name': 'You'},
        ));
      });
      _scrollToBottom();
      try {
        final serverMsg = await _repo.sendMessage(_activeConversationId!, text);
        if (mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == tempId);
            if (idx != -1) {
              _messages[idx] = serverMsg;
            } else if (!_messages.any((m) => m.id == serverMsg.id)) {
              _messages.add(serverMsg);
            }
          });
        }
      } catch (_) {}
      _pollMessages();
      _fetchAiSuggestions();
    } else if (_selectedTab == ChatTab.groups && _activeGroup != null) {
      final interviewId = _activeGroup!['id'] as int;

      final sent = await _repo.sendMeetingGroupMessage(interviewId, text);
      if (mounted) {
        if (sent != null && sent['message'] is Map) {
          final newMsg = (sent['message'] as Map).cast<String, dynamic>();
          setState(() {
            if (!_groupMessages.any((m) => m['id'] == newMsg['id'])) {
              _groupMessages.add(newMsg);
            }
          });
        }
        _scrollToBottom();
        _pollGroupMessages();
        _fetchGroupAiSuggestions();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _fetchAiSuggestions() async {
    final typedDraft = _textController.text.trim();
    final last = _messages.isNotEmpty ? _messages.last.body : '';
    setState(() => _isLoadingSuggestions = true);
    final suggestions = await _repo.getAiSuggestions(
      last,
      context: "Recruiting conversation with ${_activeContact?.name ?? 'candidate'}",
      draft: typedDraft,
    );
    if (!mounted) return;
    setState(() {
      _aiSuggestions = suggestions;
      _isLoadingSuggestions = false;
    });
  }

  Future<void> _fetchGroupAiSuggestions() async {
    final typedDraft = _textController.text.trim();
    final last = _groupMessages.isNotEmpty ? _groupMessages.last['body']?.toString() ?? '' : '';
    setState(() => _isLoadingSuggestions = true);
    final suggestions = await _repo.getAiSuggestions(
      last,
      context: "Live technical meeting group: ${_activeGroup?['title'] ?? 'Interview'}",
      draft: typedDraft,
    );
    if (!mounted) return;
    setState(() {
      _aiSuggestions = suggestions;
      _isLoadingSuggestions = false;
    });
  }

  void _showRenameGroupDialog() {
    if (_activeGroup == null) return;
    final titleCtrl = TextEditingController(text: _activeGroup!['title'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2030),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFFD946EF), size: 20),
            SizedBox(width: 8),
            Text('Rename Meeting Group', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: titleCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Group Name',
            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFF13141F),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white))),
          ElevatedButton(
            onPressed: () async {
              final newTitle = titleCtrl.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(ctx);
                final interviewId = _activeGroup!['id'] as int;
                setState(() {
                  _activeGroup!['title'] = newTitle;
                });
                await _repo.updateMeetingGroup(interviewId: interviewId, title: newTitle);
                _fetchMeetingGroups();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD946EF)),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddFriendDialog() {
    if (_activeGroup == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2030),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1, color: Color(0xFF38BDF8), size: 20),
            SizedBox(width: 8),
            Text('Add Friend to Group', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: _contacts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No contacts available to add.', style: TextStyle(color: Color(0xFF94A3B8))),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _contacts.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF2E324D), height: 1),
                  itemBuilder: (context, idx) {
                    final c = _contacts[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary,
                        child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                      title: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(c.headline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final interviewId = _activeGroup!['id'] as int;
                          await _repo.updateMeetingGroup(interviewId: interviewId, addUserId: c.id);
                          _fetchMeetingGroups();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF10B981),
                              content: Text('${c.name} added to this group!'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Add', style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    final hasActiveDirect = _activeContact != null;
    final hasActiveGroup = _activeGroup != null;
    final showMobileChat = !isDesktop && (hasActiveDirect || hasActiveGroup);

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
                          // Left pane
                          if (isDesktop || !showMobileChat)
                            SizedBox(
                              width: isDesktop ? 350 : double.infinity,
                              child: _buildContactsAndGroupsPane(isDesktop),
                            ),

                          if (isDesktop)
                            const VerticalDivider(color: AppColors.border, width: 1),

                          // Right pane
                          if (isDesktop || showMobileChat)
                            Expanded(
                              child: _selectedTab == ChatTab.direct
                                  ? _buildDirectChatPane(isDesktop, showMobileChat)
                                  : _buildGroupChatPane(isDesktop, showMobileChat),
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

  Widget _buildContactsAndGroupsPane(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header & Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Chats & Channels', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8), size: 18),
                    tooltip: 'Refresh',
                    onPressed: () {
                      _fetchContacts();
                      _fetchMeetingGroups();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Segmented Tabs: Direct vs Meeting Groups
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF161828),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedTab = ChatTab.direct);
                          if (_contacts.isNotEmpty && _activeContact == null) {
                            _selectContact(_contacts.first);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTab == ChatTab.direct ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_outline, size: 15, color: Colors.white),
                              SizedBox(width: 6),
                              Text('1-on-1 Direct', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedTab = ChatTab.groups);
                          if (_meetingGroups.isNotEmpty && _activeGroup == null) {
                            _selectGroup(_meetingGroups.first);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTab == ChatTab.groups ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.groups_outlined, size: 15, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Meeting Groups', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
        ),
        const Divider(color: AppColors.border, height: 1),

        // List Content
        Expanded(
          child: _selectedTab == ChatTab.direct
              ? _buildDirectList()
              : _buildGroupList(),
        ),
      ],
    );
  }

  Widget _buildDirectList() {
    if (_isLoadingContacts) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_contacts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No contacts found yet. Apply to jobs or connect with recruiters.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12), textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
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
                      Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(c.headline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupList() {
    if (_isLoadingGroups) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_meetingGroups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No live meeting groups yet. Start or join an interview to activate group chats.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12), textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      itemCount: _meetingGroups.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E2030), height: 1),
      itemBuilder: (ctx, idx) {
        final g = _meetingGroups[idx];
        final isSelected = _activeGroup?['id'] == g['id'];
        final status = (g['status'] ?? 'SCHEDULED').toString().toUpperCase();
        final isCompleted = status == 'COMPLETED';

        return InkWell(
          onTap: () => _selectGroup(g),
          child: Container(
            color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.accentCyan.withOpacity(0.15) : AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isCompleted ? AppColors.accentCyan.withOpacity(0.4) : AppColors.success.withOpacity(0.4)),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle_outline : Icons.videocam_outlined,
                    color: isCompleted ? AppColors.accentCyan : AppColors.success,
                    size: 18,
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
                              g['title'] ?? 'Interview Session',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCompleted ? AppColors.accentCyan.withOpacity(0.2) : AppColors.success.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isCompleted ? 'COMPLETED' : 'LIVE',
                              style: TextStyle(
                                color: isCompleted ? AppColors.accentCyan : AppColors.success,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${g['role'] ?? "Tech Role"} • ${g['company'] ?? "TalentAI"}',
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
    );
  }

  Widget _buildDirectChatPane(bool isDesktop, bool showMobileChat) {
    final myUserId = ref.watch(authProvider).user?.id;

    if (_activeContact == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_chat_unread_outlined, size: 54, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 14),
            const Text('Select a contact to view conversation', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header
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
                    Text(_activeContact!.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(_activeContact!.headline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/live-interview?room=direct_${_activeContact!.id}'),
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

        // Messages
        Expanded(
          child: _isLoadingMessages
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _messages.isEmpty
                  ? Center(
                      child: Text('No messages yet. Send a greeting to start chatting!', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
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
                              border: Border.all(color: isMe ? AppColors.primary.withOpacity(0.5) : const Color(0xFF2E324D)),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(m.body, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                                const SizedBox(height: 4),
                                Text(
                                  m.createdAt.length >= 16 ? m.createdAt.substring(11, 16) : '',
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),

        _buildSuggestionsAndInput(),
      ],
    );
  }

  Widget _buildGroupChatPane(bool isDesktop, bool showMobileChat) {
    final currentUserName = ref.watch(authProvider).user?.fullName ?? 'You';

    if (_activeGroup == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_outlined, size: 54, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 14),
            const Text('Select a meeting group to view live transcript & chat', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          ],
        ),
      );
    }

    final roomId = _activeGroup!['room_id'] ?? '';
    final role = _activeGroup!['role'] ?? 'Technical Role';
    final company = _activeGroup!['company'] ?? 'TalentAI';

    return Column(
      children: [
        // Meeting Group Header
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
                  onPressed: () => setState(() => _activeGroup = null),
                ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                ),
                child: const Icon(Icons.forum_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(_activeGroup!['title'] ?? 'Meeting Group', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 14, color: Color(0xFFD946EF)),
                          tooltip: 'Rename Group',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _showRenameGroupDialog,
                        ),
                      ],
                    ),
                    Text('$role • $company', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1, size: 18, color: Color(0xFF38BDF8)),
                tooltip: 'Add Friend / Candidate to Group',
                onPressed: _showAddFriendDialog,
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () => context.go('/live-interview?room=$roomId&id=${_activeGroup!['id']}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.videocam, size: 15),
                label: Text(isDesktop ? 'Join Live Room' : 'Join', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Group Messages
        Expanded(
          child: _groupMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_outlined, size: 40, color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 8),
                      const Text('No live meeting messages recorded yet. Start discussion!', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _groupMessages.length,
                  itemBuilder: (ctx, idx) {
                    final m = _groupMessages[idx];
                    final sender = m['sender']?.toString() ?? 'Participant';
                    final isMe = sender == 'You' || sender.toLowerCase().contains(currentUserName.toLowerCase());
                    final body = (m['body'] ?? m['text'] ?? '').toString();
                    final createdAt = (m['created_at'] ?? m['time'] ?? '').toString();

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
                          border: Border.all(color: isMe ? AppColors.primary.withOpacity(0.5) : const Color(0xFF2E324D)),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe) ...[
                              Text(sender, style: const TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                            ],
                            Text(body, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                            const SizedBox(height: 4),
                            Text(
                              createdAt.length >= 16 ? createdAt.substring(11, 16) : '',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        _buildSuggestionsAndInput(),
      ],
    );
  }

  Widget _buildSuggestionsAndInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AI Auto-Suggestions Bar
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
                const Text('AI Suggestions:', style: TextStyle(color: Color(0xFFD946EF), fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _isLoadingSuggestions
                          ? [
                              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Color(0xFFD946EF), strokeWidth: 2)),
                              const SizedBox(width: 8),
                              const Text('Generating Gemini suggestions...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            ]
                          : _aiSuggestions.map((s) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  backgroundColor: const Color(0xFF1E2138),
                                  side: BorderSide(color: const Color(0xFFD946EF).withOpacity(0.35)),
                                  label: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11)),
                                  onPressed: () {
                                    setState(() => _textController.text = s);
                                  },
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
                tooltip: 'Get AI Suggestions',
                onPressed: _selectedTab == ChatTab.direct ? _fetchAiSuggestions : _fetchGroupAiSuggestions,
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: _selectedTab == ChatTab.direct ? 'Type your message...' : 'Chat with live meeting participants...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
