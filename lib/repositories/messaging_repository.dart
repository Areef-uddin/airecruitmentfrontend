import 'package:dio/dio.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';

class ChatContact {
  final int id;
  final String name;
  final String email;
  final String role;
  final String headline;
  final int? conversationId;
  final Map<String, dynamic>? lastMessage;
  final int unreadCount;

  ChatContact({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.headline,
    this.conversationId,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      headline: json['headline'] ?? '',
      conversationId: json['conversation_id'],
      lastMessage: json['last_message'],
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}

class ChatMessageItem {
  final int id;
  final int conversationId;
  final Map<String, dynamic>? sender;
  final String body;
  final bool isRead;
  final String createdAt;

  ChatMessageItem({
    required this.id,
    required this.conversationId,
    this.sender,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatMessageItem(
      id: json['id'] ?? 0,
      conversationId: json['conversation'] ?? 0,
      sender: json['sender'],
      body: json['body'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class MessagingRepository {
  final Dio _dio = ApiClient().dio;

  Future<List<ChatContact>> getContacts() async {
    try {
      final response = await _dio.get(ApiConfig.chatContacts);
      final List list = response.data['contacts'] ?? [];
      return list.map((c) => ChatContact.fromJson(c)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getOrCreateConversation(int recipientId, {String? initialMessage}) async {
    final response = await _dio.post(
      ApiConfig.conversations,
      data: {
        'recipient_id': recipientId,
        'subject': 'Direct Message',
        if (initialMessage != null && initialMessage.isNotEmpty) 'message': initialMessage,
      },
    );
    return response.data;
  }

  Future<List<ChatMessageItem>> getMessages(int conversationId) async {
    try {
      final response = await _dio.get(ApiConfig.conversationMessages(conversationId));
      final List list = response.data is List ? response.data : (response.data['results'] ?? []);
      return list.map((m) => ChatMessageItem.fromJson(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<ChatMessageItem> sendMessage(int conversationId, String body) async {
    final response = await _dio.post(
      ApiConfig.conversationMessages(conversationId),
      data: {'body': body},
    );
    return ChatMessageItem.fromJson(response.data);
  }

  Future<List<String>> getAiSuggestions(String lastMessage, {String? context, String? draft}) async {
    try {
      final response = await _dio.post(
        ApiConfig.chatAiSuggestions,
        data: {
          'last_message': lastMessage,
          if (context != null) 'context': context,
          if (draft != null && draft.isNotEmpty) 'draft': draft,
        },
      );
      final List list = response.data['suggestions'] ?? [];
      return list.map((s) => s.toString()).toList();
    } catch (_) {
      if (draft != null && draft.isNotEmpty) {
        return [
          draft,
          'I wanted to touch base regarding: $draft',
        ];
      }
      return [
        "Hello! Thank you for getting in touch.",
        "Could we schedule a quick call this week?",
        "Looking forward to hearing from you!",
      ];
    }
  }

  Future<List<Map<String, dynamic>>> getMeetingGroups() async {
    try {
      final response = await _dio.get(ApiConfig.chatMeetingGroups);
      final List list = response.data['groups'] ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> sendMeetingGroupMessage(int interviewId, String body) async {
    try {
      final response = await _dio.post(
        ApiConfig.chatMeetingGroups,
        data: {'interview_id': interviewId, 'text': body},
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateMeetingGroup({required int interviewId, String? title, int? addUserId}) async {
    try {
      await _dio.patch(
        ApiConfig.chatMeetingGroups,
        data: {
          'interview_id': interviewId,
          if (title != null && title.isNotEmpty) 'title': title,
          if (addUserId != null) 'add_user_id': addUserId,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
