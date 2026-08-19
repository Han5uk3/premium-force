import 'package:premium_force_main/api/api_result.dart';
import 'package:premium_force_main/api/v2_client.dart';
import 'package:premium_force_main/models/v2/notification_v2.dart';
import 'package:premium_force_main/utils/json_utils.dart';

/// Client for the customer in-app notification centre (`/api/v2/notifications`).
///
/// The server is the record of truth for the feed: push messages only announce
/// that something happened, while read state, deletion and the unread badge all
/// live behind these endpoints so they stay consistent across the customer's
/// devices.
///
/// Usage:
/// ```dart
/// final result = await NotificationApiV2().getNotifications(page: 1);
/// if (result.hasData) render(result.data!.notifications);
/// ```
class NotificationApiV2 extends V2ApiClient {
  static final NotificationApiV2 _instance = NotificationApiV2._internal();
  factory NotificationApiV2() => _instance;

  NotificationApiV2._internal();

  /// One page of notifications, newest first, plus the account-wide unread
  /// count.
  Future<ApiResult<NotificationFeedPage>> getNotifications({
    int page = 1,
    int limit = 10,
  }) {
    return request(
      () => dio.get(
        'notifications',
        queryParameters: {'page': page, 'limit': limit},
      ),
      parse: (payload) => NotificationFeedPage.fromJson(asMap(payload)),
    );
  }

  /// Mark one notification as read.
  Future<ApiResult<bool>> markAsRead(String notificationId) {
    return request(
      () => dio.patch('notifications/$notificationId/read'),
      parse: (_) => true,
    );
  }

  /// Mark every notification as read, clearing the badge in one call.
  Future<ApiResult<bool>> markAllAsRead() {
    return request(
      () => dio.patch('notifications/read-all'),
      parse: (_) => true,
    );
  }

  /// Delete one notification.
  Future<ApiResult<bool>> deleteNotification(String notificationId) {
    return request(
      () => dio.delete('notifications/$notificationId'),
      parse: (_) => true,
    );
  }

  /// Delete the whole feed.
  Future<ApiResult<bool>> clearAll() {
    return request(
      () => dio.delete('notifications/clear-all'),
      parse: (_) => true,
    );
  }
}
