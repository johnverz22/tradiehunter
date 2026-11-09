import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../models/marketplace.dart';
import '../network/api_error.dart';
import 'profile_repository.dart';

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
  final _reconnectingController = StreamController<void>.broadcast();
  final _reconnectedController = StreamController<void>.broadcast();
  bool _hubConnected = false;

  /// Stream of real-time messages pushed from the server via SignalR.
  Stream<ChatMessage> get onNewMessage => _messageController.stream;

  /// Fires when the automatic-reconnect policy drops the live connection.
  /// Server-side group membership does not survive reconnect — listeners must
  /// re-join their job group and reconcile history when [onReconnected] fires.
  Stream<void> get onReconnecting => _reconnectingController.stream;

  /// Fires once per successful reconnect. Re-invoke [joinJob] and re-read
  /// history to backfill anything missed while disconnected.
  Stream<void> get onReconnected => _reconnectedController.stream;

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

    _connection!.onreconnecting(({error}) => _reconnectingController.add(null));
    _connection!.onreconnected(
      ({connectionId}) => _reconnectedController.add(null),
    );

    await _connection!.start();
    _hubConnected = true;
  }

  Future<void> joinJob(String jobId) async {
    await _connection?.invoke('JoinJob', args: [jobId]);
  }

  /// Leaves the job's chat group. The hub connection itself stays alive —
  /// other screens may still be subscribed, and the next screen only needs to
  /// join its own group.
  Future<void> leaveJob(String jobId) async {
    await _connection?.invoke('LeaveJob', args: [jobId]);
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
    _reconnectingController.close();
    _reconnectedController.close();
    disconnectHub();
  }

  // ── Inbox summaries ──────────────────────────────────────────────────────

  /// GET /api/chat/conversations — one row per two-party job thread with the
  /// counterparty name, real preview and real unread count. Throws
  /// [ProfileApiException] on failure so the inbox can show a retryable error
  /// instead of an empty list that looks like "no messages".
  Future<List<ConversationSummary>> getConversations() async {
    final token = await _storage.read(key: 'jwt_token');
    try {
      final resp = await _dio.get(
        '/api/chat/conversations',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (resp.data as List)
          .cast<Map<String, dynamic>>()
          .map(ConversationSummary.fromJson)
          .toList();
    } catch (e) {
      throw ProfileApiException(
        e is DioException
            ? friendlyDioError(e, tag: 'Chat.conversations')
            : 'Could not load conversations. Try again.',
      );
    }
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
    } catch (e) {
      // Truthful failure: an empty result would disguise a fetch error (or a
      // 404 for a non-participant) as "no messages yet".
      throw ProfileApiException(
        e is DioException
            ? friendlyDioError(e, tag: 'Chat.history')
            : 'Could not load messages. Try again.',
      );
    }
  }

  // ── REST send (hub is the primary path) ──────────────────────────────────

  /// Throws when the hub is not connected — a silent no-op would leave the
  /// optimistic bubble looking sent when nothing reached the server.
  Future<void> sendMessageViaHub(String jobId, String text) async {
    final conn = _connection;
    if (conn == null || conn.state != HubConnectionState.Connected) {
      throw StateError('Chat connection is not available.');
    }
    await conn.invoke('SendMessage', args: [jobId, text]);
  }

  /// Fallback REST send when the hub is not connected.
  /// Returns the persisted message so the caller can swap its optimistic
  /// bubble for the real server row. Throws on failure.
  Future<ChatMessage> sendMessageViaRest(String jobId, String text) async {
    final token = await _storage.read(key: 'jwt_token');
    try {
      final resp = await _dio.post(
        '/api/jobs/$jobId/messages',
        data: {'content': text},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return ChatMessage.fromJson(resp.data as Map<String, dynamic>);
    } catch (e) {
      throw ProfileApiException(
        e is DioException
            ? friendlyDioError(e, tag: 'Chat.send')
            : 'Message could not be sent. Try again.',
      );
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
    } catch (e) {
      // Swallow — UI shows success state regardless of transient failures in demo.
      throw ProfileApiException(
        e is DioException
            ? friendlyDioError(e, tag: 'Reviews.submit')
            : 'Could not submit review. Try again.',
      );
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
      final items =
          (data['items'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(Review.fromJson)
              .toList() ??
          const [];
      return ReviewPage(
        items: items,
        totalCount: (data['totalCount'] as num?)?.toInt() ?? items.length,
        page: page,
        pageSize: pageSize,
      );
    } catch (_) {
      // Stub fallback while backend is not reachable.
      throw const ProfileApiException('Could not load reviews. Try again.');
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
