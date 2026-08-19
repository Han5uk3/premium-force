import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/notification_api_v2.dart';
import 'package:premium_force_main/models/v2/notification_v2.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';

/// Loading state of the notification centre.
enum NotificationFeedStatus { initial, loading, loaded, failure }

/// State for the in-app notification centre.
///
/// The server owns the feed: read state, deletion and the unread count are all
/// server-side, so the same inbox follows the customer across devices. Push
/// messages are only a signal that something arrived — [refresh] is what pulls
/// the new entry in.
///
/// Mutations are applied locally first and rolled back if the call fails, so
/// tapping a notification feels immediate without risking a lie about what the
/// server holds.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({NotificationApiV2? api})
    : _api = api ?? NotificationApiV2();

  final NotificationApiV2 _api;

  static const int _pageSize = 20;

  NotificationFeedStatus _status = NotificationFeedStatus.initial;
  NotificationFeedStatus get status => _status;

  List<NotificationV2> _notifications = const [];
  List<NotificationV2> get notifications => _notifications;

  int _unreadCount = 0;

  /// Account-wide unread count, for the badge — not just this page's.
  int get unreadCount => _unreadCount;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _page = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _page < _totalPages;
  bool get isEmpty =>
      _notifications.isEmpty && _status == NotificationFeedStatus.loaded;

  /// Load the first page, replacing whatever is held.
  ///
  /// [silent] keeps the current list on screen while refetching, which is what
  /// a push-triggered refresh wants — the list must not flash back to a spinner
  /// while the customer is reading it.
  Future<void> refresh({bool silent = false}) async {
    if (!UserLocalStorage.isLoggedIn) {
      _notifications = const [];
      _unreadCount = 0;
      _status = NotificationFeedStatus.loaded;
      notifyListeners();
      return;
    }

    if (!silent) {
      _status = NotificationFeedStatus.loading;
      _errorMessage = null;
      notifyListeners();
    }

    final result = await _api.getNotifications(page: 1, limit: _pageSize);

    if (result.hasData) {
      final feed = result.data!;
      _notifications = feed.notifications;
      _unreadCount = feed.unreadCount;
      _page = feed.page;
      _totalPages = feed.totalPages;
      _status = NotificationFeedStatus.loaded;
      _errorMessage = null;
    } else {
      // A silent refresh must not replace a readable list with an error state.
      if (!silent) {
        _status = NotificationFeedStatus.failure;
        _errorMessage = result.message;
      }
      debugPrint('🔔 Feed │ refresh failed: ${result.message}');
    }

    notifyListeners();
  }

  /// Append the next page, if there is one.
  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    final result = await _api.getNotifications(
      page: _page + 1,
      limit: _pageSize,
    );

    if (result.hasData) {
      final feed = result.data!;
      // De-duplicate: a notification arriving between two page reads shifts the
      // window, which would otherwise repeat an entry.
      final seen = _notifications.map((n) => n.id).toSet();
      _notifications = [
        ..._notifications,
        ...feed.notifications.where((n) => !seen.contains(n.id)),
      ];
      _unreadCount = feed.unreadCount;
      _page = feed.page;
      _totalPages = feed.totalPages;
    } else {
      debugPrint('🔔 Feed │ load more failed: ${result.message}');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Mark one notification as read, optimistically.
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1 || _notifications[index].isRead) return;

    final previous = _notifications[index];
    _replaceAt(index, previous.copyWith(isRead: true));
    _unreadCount = (_unreadCount - 1).clamp(0, 1 << 30);
    notifyListeners();

    final result = await _api.markAsRead(notificationId);
    if (!result.success) {
      _replaceAt(index, previous);
      _unreadCount += 1;
      notifyListeners();
    }
  }

  /// Mark every notification as read.
  Future<bool> markAllAsRead() async {
    if (_unreadCount == 0 && _notifications.every((n) => n.isRead)) return true;

    final previous = _notifications;
    final previousCount = _unreadCount;

    _notifications = _notifications
        .map((n) => n.isRead ? n : n.copyWith(isRead: true))
        .toList();
    _unreadCount = 0;
    notifyListeners();

    final result = await _api.markAllAsRead();
    if (!result.success) {
      _notifications = previous;
      _unreadCount = previousCount;
      _errorMessage = result.message;
      notifyListeners();
    }
    return result.success;
  }

  /// Delete one notification.
  Future<bool> deleteNotification(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return false;

    final removed = _notifications[index];
    _notifications = List<NotificationV2>.from(_notifications)
      ..removeAt(index);
    if (!removed.isRead) {
      _unreadCount = (_unreadCount - 1).clamp(0, 1 << 30);
    }
    notifyListeners();

    final result = await _api.deleteNotification(notificationId);
    if (!result.success) {
      _notifications = List<NotificationV2>.from(_notifications)
        ..insert(index, removed);
      if (!removed.isRead) _unreadCount += 1;
      _errorMessage = result.message;
      notifyListeners();
    }
    return result.success;
  }

  /// Delete the whole feed.
  Future<bool> clearAll() async {
    final previous = _notifications;
    final previousCount = _unreadCount;

    _notifications = const [];
    _unreadCount = 0;
    _page = 1;
    _totalPages = 1;
    _status = NotificationFeedStatus.loaded;
    notifyListeners();

    final result = await _api.clearAll();
    if (!result.success) {
      _notifications = previous;
      _unreadCount = previousCount;
      _errorMessage = result.message;
      notifyListeners();
    }
    return result.success;
  }

  /// Drop everything held, on logout.
  void reset() {
    _notifications = const [];
    _unreadCount = 0;
    _page = 1;
    _totalPages = 1;
    _errorMessage = null;
    _status = NotificationFeedStatus.initial;
    notifyListeners();
  }

  void _replaceAt(int index, NotificationV2 notification) {
    _notifications = List<NotificationV2>.from(_notifications)
      ..[index] = notification;
  }
}
