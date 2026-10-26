import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/notification_repository.dart';

final notificationRepoProvider = Provider((ref) => NotificationRepository());

final notificationsProvider = FutureProvider.autoDispose<List<AppNotificationModel>>((ref) async {
  final repo = ref.watch(notificationRepoProvider);
  return repo.getNotifications();
});
