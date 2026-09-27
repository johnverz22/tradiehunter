import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../models/marketplace.dart';

/// Repository for chat messages.
///
/// REST half: GET/POST /api/jobs/:jobId/messages (cursor-based pagination).
/// SignalR half: ChatHub at /hubs/chat — JoinJob, SendMessage, MarkRead,
/// and inbound NewChatMessage events.
class ChatRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  HubConnection? _connection;
  final _messageController = StreamController<ChatMessage>.broadcast();
  bool _hubConnected = false;

  /// Stream of real-time messages pushed from the server via SignalR.
  Stream<ChatMessage> get onNewMessage => _messageController.stream;

  ChatRepository(this._dio, this._storage);

  // ── Hub lifecycle ─────────────────────────────────────────────────────────

  Future<void> connectHub(String baseUrl) async {
    if (_hubConnected) return;

    final token = await _storage.read(key: 'jwt_token');

    _connection = HubConnectionBuilder()
        .withUrl(
          '$baseUrl/hubs/chat',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on('NewChatMessage', (args) {
      if (args == null || args.isEmpty) return;
      final data = args[0] as Map<String, dynamic>?;
      if (data != null) {
        _messageController.add(ChatMessage.fromJson(data));
      }
    });

    await _connection!.start();
    _hubConnected = true;
  }

  Future<void> joinJob(String jobId) async {
    await _connection?.invoke('JoinJob', args: [jobId]);
  }

  Future<void> leaveJob(String jobId) async {
    await _connection?.invoke('LeaveJob', args: [jobId]);
    _hubConnected = false;
  }

  Future<void> markRead(String jobId, int messageId) async {
    await _connection?.invoke('MarkRead', args: [jobId, messageId]);
  }

  Future<void> disconnectHub() async {
    await _connection?.stop();
    _connection = null;
    _hubConnected = false;
  }

  void dispose() {
    _messageController.close();
    disconnectHub();
  }

  // ── REST history (cursor-based pagination) ────────────────────────────────

  /// Fetch paginated message history.
  /// Pass [beforeId] to load messages older than the current page (scroll-back).
  Future<ChatHistoryResult> getMessages(
    String jobId, {
    int? beforeId,
    int pageSize = 30,
  }) async {
    final token = await _storage.read(key: 'jwt_token');
    try {
      final resp = await _dio.get(
        '/api/jobs/$jobId/messages',
        queryParameters: {
          if (beforeId != null) 'beforeId': beforeId,
          'pageSize': pageSize,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = resp.data as Map<String, dynamic>;
      final msgs = (data['messages'] as List)
          .cast<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();

      return ChatHistoryResult(
        messages: msgs,
        hasMore: data['hasMore'] as bool? ?? false,
        oldestId: data['oldestId'] as int?,
      );
    } catch (_) {
      // Fallback: return empty result on error
      return const ChatHistoryResult(messages: [], hasMore: false);
    }
  }

  // ── REST send (hub is the primary path) ──────────────────────────────────

  Future<void> sendMessageViaHub(String jobId, String text) async {
    await _connection?.invoke('SendMessage', args: [jobId, text]);
  }

  /// Fallback REST send if hub is not connected.
  Future<void> sendMessageViaRest(String jobId, String text) async {
    final token = await _storage.read(key: 'jwt_token');
    try {
      await _dio.post(
        '/api/jobs/$jobId/messages',
        data: {'content': text},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Swallow — optimistic UI already added the message locally.
    }
  }
}

/// Result of a paginated history fetch.
class ChatHistoryResult {
  final List<ChatMessage> messages;
  final bool hasMore;
  final int? oldestId;

  const ChatHistoryResult({
    required this.messages,
    required this.hasMore,
    this.oldestId,
  });
}

class ReviewsRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ReviewsRepository(this._dio, this._storage);

  Future<String?> _token() => _storage.read(key: 'jwt_token');
  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  // ── Submit review ─────────────────────────────────────────────────────────

  /// POST /api/jobs/:jobId/reviews
  /// [revieweeId] is the user receiving the review.
  Future<void> submitReview(
    String jobId,
    int rating,
    String? comment, {
    required String revieweeId,
  }) async {
    final token = await _token();
    final data = <String, dynamic>{
      'revieweeId': revieweeId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    };
    try {
      await _dio.post(
        '/api/jobs/$jobId/reviews',
        data: data,
        options: token != null ? _auth(token) : null,
      );
    } catch (_) {
      // Swallow — UI shows success state regardless of transient failures in demo.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  // ── Fetch reviews for a user (paginated) ──────────────────────────────────

  /// GET /api/users/:userId/reviews?page=&pageSize=
  Future<ReviewPage> getReviewsForUser(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    final token = await _token();
    try {
      final resp = await _dio.get(
        '/api/users/$userId/reviews',
        queryParameters: {'page': page, 'pageSize': pageSize},
        options: token != null ? _auth(token) : null,
      );
      final data = resp.data as Map<String, dynamic>;
      final items = (data['items'] as List?)
          ?.cast<Map<String, dynamic>>()
          .map(Review.fromJson)
          .toList() ?? const [];
      return ReviewPage(
        items: items,
        totalCount: (data['totalCount'] as num?)?.toInt() ?? items.length,
        page: page,
        pageSize: pageSize,
      );
    } catch (_) {
      // Stub fallback while backend is not reachable.
      return const ReviewPage(items: [], totalCount: 0, page: 1, pageSize: 10);
    }
  }

  // ── Fetch public profile with aggregated rating (M4-10) ───────────────────

  /// GET /api/profile/:userId
  Future<UserProfile?> getProfile(String userId) async {
    final token = await _token();
    try {
      final resp = await _dio.get(
        '/api/profile/$userId',
        options: token != null ? _auth(token) : null,
      );
      return UserProfile.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// Paginated result wrapper for reviews.
class ReviewPage {
  final List<Review> items;
  final int totalCount;
  final int page;
  final int pageSize;

  const ReviewPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  bool get hasMore => page * pageSize < totalCount;
}

// ── Schedule repository ───────────────────────────────────────────────────────

/// Schedule data model (mirrors ScheduleDto on the backend).
class ScheduleInfo {
  final int jobId;
  final DateTime? scheduledDateUtc;
  final String? scheduledTimeSlot; // Morning | Afternoon | Evening
  final String scheduleStatus; // None | Proposed | Confirmed
  final String? proposedByUserId;

  const ScheduleInfo({
    required this.jobId,
    this.scheduledDateUtc,
    this.scheduledTimeSlot,
    required this.scheduleStatus,
    this.proposedByUserId,
  });

  factory ScheduleInfo.fromJson(Map<String, dynamic> json) => ScheduleInfo(
        jobId: (json['jobId'] as num?)?.toInt() ?? 0,
        scheduledDateUtc: json['scheduledDateUtc'] != null
            ? DateTime.parse(json['scheduledDateUtc'] as String).toUtc()
            : null,
        scheduledTimeSlot: json['scheduledTimeSlot'] as String?,
        scheduleStatus: json['scheduleStatus'] as String? ?? 'None',
        proposedByUserId: json['proposedByUserId'] as String?,
      );
}

class ScheduleRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ScheduleRepository(this._dio, this._storage);

  Future<String?> _token() => _storage.read(key: 'jwt_token');
  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  /// GET /api/jobs/:jobId/schedule
  Future<ScheduleInfo?> getSchedule(String jobId) async {
    final token = await _token();
    try {
      final resp = await _dio.get(
        '/api/jobs/$jobId/schedule',
        options: token != null ? _auth(token) : null,
      );
      return ScheduleInfo.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// POST /api/jobs/:jobId/schedule
  Future<ScheduleInfo?> proposeOrConfirm(
    String jobId, {
    required DateTime proposedDateUtc,
    required String timeSlot,
  }) async {
    final token = await _token();
    try {
      final resp = await _dio.post(
        '/api/jobs/$jobId/schedule',
        data: {
          'proposedDateUtc': proposedDateUtc.toUtc().toIso8601String(),
          'timeSlot': timeSlot,
        },
        options: token != null ? _auth(token) : null,
      );
      return ScheduleInfo.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
