import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/notification_model.dart';

class NotificationStorage {
  static const String _boxName = 'notifications_box';
  static late Box<String> _box;

  // Using a ValueNotifier to allow the UI to listen for changes
  static final ValueNotifier<List<AppNotification>> notificationsView =
      ValueNotifier<List<AppNotification>>([]);

  static Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
    _loadNotifications();
    debugPrint('💾 NotificationStorage initialized');
  }

  static void _loadNotifications() {
    final List<AppNotification> loaded = [];
    for (var i = 0; i < _box.length; i++) {
      final jsonStr = _box.getAt(i);
      if (jsonStr != null) {
        try {
          loaded.add(AppNotification.fromJson(jsonStr));
        } catch (e) {
          debugPrint('⚠️ Error loading notification at index $i: $e');
        }
      }
    }
    // Sort by timestamp descending (newest first)
    loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notificationsView.value = loaded;
  }

  static Future<void> saveNotification(AppNotification notification) async {
    await _box.add(notification.toJson());
    _loadNotifications();
    debugPrint('💾 Notification saved: ${notification.title}');
  }

  static Future<void> markAsRead(String id) async {
    final list = List<AppNotification>.from(notificationsView.value);
    final index = list.indexWhere((n) => n.id == id);
    
    if (index != -1) {
      final updated = list[index].copyWith(isRead: true);
      
      // Find the key in the box (unfortunately Hive index doesn't match our sorted list index)
      // We'll search by iterating or we could have used a map instead of a list in the box.
      // For simplicity with auto-incrementing keys:
      dynamic keyToUpdate;
      for (var key in _box.keys) {
        final jsonStr = _box.get(key);
        if (jsonStr != null) {
          final n = AppNotification.fromJson(jsonStr);
          if (n.id == id) {
            keyToUpdate = key;
            break;
          }
        }
      }

      if (keyToUpdate != null) {
        await _box.put(keyToUpdate, updated.toJson());
        _loadNotifications();
      }
    }
  }

  static Future<void> clearAll() async {
    await _box.clear();
    _loadNotifications();
    debugPrint('💾 All notifications cleared');
  }

  static Future<void> deleteNotification(String id) async {
    dynamic keyToDelete;
    for (var key in _box.keys) {
      final jsonStr = _box.get(key);
      if (jsonStr != null) {
        final n = AppNotification.fromJson(jsonStr);
        if (n.id == id) {
          keyToDelete = key;
          break;
        }
      }
    }

    if (keyToDelete != null) {
      await _box.delete(keyToDelete);
      _loadNotifications();
    }
  }
}
