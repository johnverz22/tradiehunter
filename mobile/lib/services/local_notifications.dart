import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// OS-level notifications while the app is in the foreground (QA plan §6).
///
/// FCM never shows a tray notification for a foregrounded app, and a toast is
/// easy to miss, so foreground pushes are re-posted here through the same
/// Android channels the backend targets (`channel` data key) and iOS
/// presentation levels.
class LocalNotifications {
  LocalNotifications._();

  static final LocalNotifications instance = LocalNotifications._();

  /// Channel ids. `incoming_requests` must match the backend's
  /// `PushNotificationService.IncomingRequestsChannel`.
  static const String chatChannel = 'chat';
  static const String incomingRequestsChannel = 'incoming_requests';
  static const String jobUpdatesChannel = 'job_updates';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _nextId = 0;

  /// Chat notifications reuse the job id as their id so a burst on one job
  /// updates a single entry; the base keeps those ids clear of [_nextId].
  static const int _chatIdBase = 1 << 30;

  /// Creates the Android channels and wires tap handling. [onTap] receives the
  /// FCM data map that was attached when the notification was shown.
  Future<void> init({required void Function(Map<String, dynamic>) onTap}) async {
    if (_ready) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notification'),
      // Permission is requested once by FirebaseMessaging in main().
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final data = _decode(response.payload);
        if (data != null) onTap(data);
      },
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        incomingRequestsChannel,
        'Incoming job requests',
        description: 'New job requests that need a response before they expire.',
        importance: Importance.max,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        chatChannel,
        'Messages',
        description: 'Chat messages about your jobs.',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        jobUpdatesChannel,
        'Job updates',
        description: 'Status changes, quotes and payment updates.',
        importance: Importance.high,
      ),
    );
    _ready = true;
  }

  /// Whether the user has allowed notifications. Used to fall back to the
  /// in-app notice instead of silently showing nothing.
  Future<bool> isPermitted() async {
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('LocalNotifications.isPermitted failed: $e');
      return false;
    }
  }

  /// Channel for an FCM data payload: the explicit `channel` key wins, then
  /// the notification `type`.
  static String channelFor(Map<String, dynamic> data) {
    final explicit = data['channel'];
    if (explicit is String && explicit.isNotEmpty) return explicit;
    return switch (data['type']) {
      'chat' => chatChannel,
      _ => jobUpdatesChannel,
    };
  }

  /// Posts a heads-up notification. Returns false (and shows nothing) when the
  /// plugin is not initialised or posting fails, so the caller can fall back.
  Future<bool> show({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    if (!_ready) return false;
    final channel = channelFor(data);
    final isOffer = channel == incomingRequestsChannel;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        switch (channel) {
          incomingRequestsChannel => 'Incoming job requests',
          chatChannel => 'Messages',
          _ => 'Job updates',
        },
        importance: isOffer ? Importance.max : Importance.high,
        priority: Priority.high,
        fullScreenIntent: isOffer,
        category: isOffer ? AndroidNotificationCategory.call : null,
        icon: 'ic_stat_notification',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: isOffer
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      ),
    );
    try {
      // Chat notifications collapse per job so a burst updates one entry.
      final id = channel == chatChannel
          ? (int.tryParse(data['jobId']?.toString() ?? '') ?? _nextId++) +
                _chatIdBase
          : _nextId++;
      await _plugin.show(
        id,
        title,
        body,
        details,
        payload: jsonEncode(data),
      );
      return true;
    } catch (e) {
      debugPrint('LocalNotifications.show failed: $e');
      return false;
    }
  }

  static Map<String, dynamic>? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }
}
