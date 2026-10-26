import 'package:dio/dio.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';

class AppNotificationModel {
  final int id;
  final String title;
  final String message;
  final String notificationType;
  final String link;
  final bool isRead;
  final String createdAt;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.link,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      notificationType: json['notification_type'] ?? 'SYSTEM',
      link: json['link'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class NotificationRepository {
  final Dio _dio = ApiClient().dio;

  Future<List<AppNotificationModel>> getNotifications() async {
    try {
      final response = await _dio.get(ApiConfig.notifications);
      final List list = response.data is List ? response.data : (response.data['results'] ?? []);
      return list.map((item) => AppNotificationModel.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await _dio.post('${ApiConfig.notifications}$id/read/');
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _dio.post(ApiConfig.markAllNotificationsRead);
    } catch (_) {}
  }
}
