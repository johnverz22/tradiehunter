import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Client-side notification centre (H20 mockup).
///
/// The backend has no notifications inbox endpoint yet — device push arrives
/// over Firebase Cloud Messaging and the foreground/background handlers in
/// main.dart already receive every message. This store records those runtime
/// messages (title/body/category) locally so the Notifications screen shows
/// the user's real feed, persisted across launches via SharedPreferences.
///
/// Categories mirror the H20 filter chips: jobs / payments / reminders.
class NotificationCenter extends ChangeNotifier {
  static const _storageKey = 'fixo.notifications.v1';
  static const _maxEntries = 50;

  NotificationCenter._();

  final List<ThNotification> _items = [];
  bool _loaded = false;

  /// Most recent first.
  List<ThNotification> get items => List.unmodifiable(_items);

  /// Ids the user has seen (used for unread dots).
  final Set<String> _readIds = {};

  bool isUnread(ThNotification n) => !_readIds.contains(n.id);

  int get unreadCount => _items.where(isUnread).length;

  /// Restore persisted entries + read marks. Safe to call repeatedly.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _items
          ..clear()
          ..addAll(
            decoded
                .map((e) => ThNotification.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
      }
      final readRaw = prefs.getString('$_storageKey.read');
      if (readRaw != null) {
        _readIds
          ..clear()
          ..addAll((jsonDecode(readRaw) as List<dynamic>).cast<String>());
      }
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationCenter load failed: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(_items.map((e) => e.toJson()).toList()),
      );
      await prefs.setString('$_storageKey.read', jsonEncode(_readIds.toList()));
    } catch (e) {
      debugPrint('NotificationCenter persist failed: $e');
    }
  }

  /// Record a live FCM message (title/body/category). Deduplicates by id.
  Future<void> add(ThNotification notification) async {
    if (_items.any((n) => n.id == notification.id)) return;
    _items.insert(0, notification);
    if (_items.length > _maxEntries) {
      _items.removeRange(_maxEntries, _items.length);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> markAllRead() async {
    _readIds.addAll(_items.map((n) => n.id));
    notifyListeners();
    await _persist();
  }

  Future<void> markRead(String id) async {
    _readIds.add(id);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    await _persist();
  }
}

/// One recorded notification. [category] drives the H20 filter chips.
class ThNotification {
  final String id;
  final String title;
  final String? body;
  final String category; // jobs | payments | reminders
  final DateTime receivedAt;

  const ThNotification({
    required this.id,
    required this.title,
    this.body,
    required this.category,
    required this.receivedAt,
  });

  factory ThNotification.fromRemote({
    required String? title,
    required String? body,
    required Map<String, dynamic> data,
  }) {
    // FCM messages carry a category hint in data.category when the backend
    // sends one; fall back to a title keyword match, then 'jobs'.
    final hinted = (data['category'] as String?)?.toLowerCase();
    final category = switch (hinted) {
      'payments' || 'payment' => 'payments',
      'reminders' || 'reminder' => 'reminders',
      'jobs' || 'job' => 'jobs',
      _ => _categoryFromTitle(title),
    };
    return ThNotification(
      id:
          data['messageId'] as String? ??
          'fcm-${DateTime.now().microsecondsSinceEpoch}',
      title: title ?? 'TradieHunter',
      body: body,
      category: category,
      receivedAt: DateTime.now(),
    );
  }

  static String _categoryFromTitle(String? title) {
    final t = (title ?? '').toLowerCase();
    if (t.contains('payment') || t.contains('invoice')) return 'payments';
    if (t.contains('reminder') || t.contains('schedule')) return 'reminders';
    return 'jobs';
  }

  factory ThNotification.fromJson(Map<String, dynamic> json) => ThNotification(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'TradieHunter',
    body: json['body'] as String?,
    category: json['category'] as String? ?? 'jobs',
    receivedAt:
        DateTime.tryParse(json['receivedAt'] as String? ?? '') ??
        DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'category': category,
    'receivedAt': receivedAt.toIso8601String(),
  };
}

final notificationCenterProvider = ChangeNotifierProvider<NotificationCenter>((
  ref,
) {
  final center = NotificationCenter._()..ensureLoaded();
  return center;
});
