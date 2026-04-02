import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/storage/notification_storage.dart';
import 'package:premium_force_main/models/notification_model.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:uuid/uuid.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Top-level background handler (must be a top-level / static function)
// ──────────────────────────────────────────────────────────────────────────────

/// Called by FCM when a data-only message arrives while the app is terminated
/// or in the background.  Keep this as lightweight as possible – no UI work.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized (though usually it is)
  await Firebase.initializeApp();
  
  // Initialize Hive for the background isolate
  await Hive.initFlutter();
  await NotificationStorage.init();

  debugPrint('🔔 FCM [background] │ ${message.messageId}');
  
  if (message.notification != null) {
    final notification = AppNotification(
      id: message.messageId ?? const Uuid().v4(),
      title: message.notification!.title ?? 'No Title',
      body: message.notification!.body ?? '',
      timestamp: DateTime.now(),
      data: message.data,
    );
    await NotificationStorage.saveNotification(notification);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Android notification channel
// ──────────────────────────────────────────────────────────────────────────────

const AndroidNotificationChannel
_highImportanceChannel = AndroidNotificationChannel(
  'premium_force_high_importance', // must match the channel id in the manifest
  'Premium Force Alerts',
  description: 'Booking updates and important alerts from Premium Force.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

// ──────────────────────────────────────────────────────────────────────────────
// NotificationService
// ──────────────────────────────────────────────────────────────────────────────

/// Manages FCM token lifecycle and displays local notifications for foreground
/// messages on both Android and iOS.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;

  /// The current FCM registration token (may be null before [init] is called).
  String? get fcmToken => _fcmToken;

  // ── Callback invoked when a notification is tapped (foreground or from tray)
  void Function(RemoteMessage)? onNotificationTap;

  // ── Callback invoked when a new FCM token is issued / refreshed
  void Function(String token)? onTokenRefresh;

  // ---------------------------------------------------------------------------
  // Initialise
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    // 1. Request permission (iOS / Android 13+)
    await _requestPermission();

    // 2. Set up local notifications plugin & channel
    await _initLocalNotifications();

    // 3. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 4. Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Message-opened-from-notification-tray handler
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('🔔 FCM [opened-from-tray] │ ${msg.messageId}');
      onNotificationTap?.call(msg);
    });

    // 6. Handle messages that launched the app from terminated state
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '🔔 FCM [launch-from-notification] │ ${initialMessage.messageId}',
      );
      onNotificationTap?.call(initialMessage);
    }

    // 7. Fetch + cache the FCM token
    await _fetchToken();

    // 8. Listen for token refreshes → update Hive automatically
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('🔔 FCM │ Token refreshed');
      _fcmToken = newToken;
      await UserLocalStorage.saveFcmToken(newToken);
      await _updateTokenOnBackend(newToken);
      onTokenRefresh?.call(newToken);
    });
  }

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
      '🔔 FCM │ Permission status: ${settings.authorizationStatus.name}',
    );

    // iOS: needed to receive foreground notifications as banners
    if (Platform.isIOS) {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Local notifications setup
  // ---------------------------------------------------------------------------

  Future<void> _initLocalNotifications() async {
    // Android init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS / macOS init
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false, // already requested via FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _localPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Payload is the serialised RemoteMessage JSON we stored when showing
        // the notification; decode and forward to the tap callback.
        if (details.payload != null) {
          try {
            final map = jsonDecode(details.payload!) as Map<String, dynamic>;
            final msg = RemoteMessage.fromMap(map);
            onNotificationTap?.call(msg);
          } catch (_) {}
        }
      },
    );

    // Create the Android high-importance channel once
    if (Platform.isAndroid) {
      await _localPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_highImportanceChannel);
    }
  }

  // ---------------------------------------------------------------------------
  // Foreground message handler
  // ---------------------------------------------------------------------------

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('🔔 FCM [foreground] │ ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    // Save notification to local storage
    final appNotification = AppNotification(
      id: message.messageId ?? const Uuid().v4(),
      title: notification.title ?? 'No Title',
      body: notification.body ?? '',
      timestamp: DateTime.now(),
      data: message.data,
    );
    await NotificationStorage.saveNotification(appNotification);

    await _localPlugin.show(
      // Use hashCode so successive notifications don't overwrite each other
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _highImportanceChannel.id,
          _highImportanceChannel.name,
          channelDescription: _highImportanceChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      // Serialise the full message so we can reconstruct it on tap
      payload: jsonEncode(message.toMap()),
    );
  }

  // ---------------------------------------------------------------------------
  // Token helpers
  // ---------------------------------------------------------------------------

  Future<void> _fetchToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      // Print prominently so you can copy it from the console
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // ignore: avoid_print
      print('🔔  FCM TOKEN');
      // ignore: avoid_print
      print('$_fcmToken');
      // ignore: avoid_print
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // ignore: avoid_print
      print('');
      // Persist immediately so the rest of the app can read it via Hive
      if (_fcmToken != null) {
        await UserLocalStorage.saveFcmToken(_fcmToken!);
        await _updateTokenOnBackend(_fcmToken!);
      }
    } on FirebaseException catch (e) {
      if (e.code == 'apns-token-not-set') {
        // iOS Simulator does not support APNS, so FCM cannot issue a token.
        // Push notifications will only work on a physical iOS device.
        debugPrint(
          '🔔 FCM │ ⚠️  Running on iOS Simulator — FCM tokens are not '
          'available. Test push notifications on a real device.',
        );
      } else {
        debugPrint('🔔 FCM │ Token fetch error: ${e.code} – ${e.message}');
      }
    } catch (e) {
      debugPrint('🔔 FCM │ Token fetch error: $e');
    }
  }

  /// Call this to force-fetch the current token (e.g., after login).
  Future<String?> getToken() async {
    if (_fcmToken == null) await _fetchToken();
    return _fcmToken;
  }

  /// Deletes the FCM token (call on logout so this device stops receiving
  /// notifications for the previous user).
  Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
      _fcmToken = null;
      await UserLocalStorage.clearFcmToken();
      debugPrint('🔔 FCM │ Token deleted');
    } catch (e) {
      debugPrint('🔔 FCM │ Token delete error: $e');
    }
  }

  /// Synchronise the local FCM token with the backend if the user is logged in.
  Future<void> _updateTokenOnBackend(String fcmToken) async {
    final uid = UserLocalStorage.getUserId();
    final authToken = UserLocalStorage.getToken();

    if (uid != null && uid.isNotEmpty) {
      debugPrint('🔔 FCM │ Syncing token with backend for user: $uid');
      try {
        final response = await ApiService().updateFcmToken(
          userid: uid,
          fcmToken: fcmToken,
          token: authToken,
        );
        if (response['success'] == true) {
          debugPrint('✅ FCM │ Token synced with backend');
        } else {
          debugPrint('⚠️ FCM │ Token sync failed: ${response['message']}');
        }
      } catch (e) {
        debugPrint('❌ FCM │ Token sync error: $e');
      }
    } else {
      debugPrint('🔔 FCM │ User not logged in, skipping backend sync');
    }
  }
}
