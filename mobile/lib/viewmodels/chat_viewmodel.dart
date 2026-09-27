import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/marketplace.dart';
import '../repositories/chat_reviews_repository.dart';
import 'auth_viewmodel.dart';
import 'jobs_viewmodel.dart';

// ── Chat state ────────────────────────────────────────────────────────────────

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool hasMore;
  final int? oldestId; // cursor for scroll-back
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = false,
    this.oldestId,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? hasMore,
    int? oldestId,
    String? error,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        oldestId: oldestId ?? this.oldestId,
        error: error,
      );
}

// ── ChatNotifier ──────────────────────────────────────────────────────────────

/// ViewModel for the Chat screen (M3-07).
///
/// Manages message list, hub subscription, and pagination.
/// Connects to ChatHub on [init], exposes [sendMessage] and [loadMore].
class ChatNotifier extends StateNotifier<ChatState> {
  final String jobId;
  final ChatRepository _repo;
  String _myUserId;

  StreamSubscription<ChatMessage>? _hubSub;
  bool _hubReady = false;

  ChatNotifier({
    required this.jobId,
    required ChatRepository repo,
    required String myUserId,
  })  : _repo = repo,
        _myUserId = myUserId,
        super(const ChatState());

  /// Call once when the chat screen mounts.
  Future<void> init(String baseUrl) async {
    state = state.copyWith(isLoading: true);

    // Start REST history load in parallel with hub connect.
    await Future.wait([
      _loadInitialHistory(),
      _connectHub(baseUrl),
    ]);
  }

  Future<void> _loadInitialHistory() async {
    try {
      final result = await _repo.getMessages(jobId);
      // Messages come newest-first from server; reverse so oldest is at top.
      final reversed = result.messages.reversed.toList();
      state = state.copyWith(
        messages: reversed,
        hasMore: result.hasMore,
        oldestId: result.oldestId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _connectHub(String baseUrl) async {
    try {
      await _repo.connectHub(baseUrl);
      await _repo.joinJob(jobId);
      _hubReady = true;

      _hubSub = _repo.onNewMessage.listen((msg) {
        // Tag sentByMe using our own userId since hub broadcasts don't carry it.
        final tagged = ChatMessage(
          id: msg.id,
          jobId: msg.jobId,
          senderId: msg.senderId,
          senderName: msg.senderName,
          sentByMe: msg.senderId == _myUserId,
          text: msg.text,
          imageUrl: msg.imageUrl,
          sentAtUtc: msg.sentAtUtc,
          readAtUtc: msg.readAtUtc,
        );

        // Append to bottom (dedup by ID in case REST already fetched it).
        if (!state.messages.any((m) => m.id == tagged.id)) {
          state = state.copyWith(messages: [...state.messages, tagged]);
        } else {
          // Replace the optimistic local message with the confirmed server one.
          state = state.copyWith(
            messages: state.messages
                .map((m) => m.id == tagged.id ? tagged : m)
                .toList(),
          );
        }
      });
    } catch (e) {
      // Hub failure is non-fatal — REST history still loads.
      state = state.copyWith(error: 'Real-time unavailable: ${e.toString()}');
    }
  }

  /// Send a message. Uses hub when connected, REST as fallback.
  /// Optimistically appends a local message immediately for snappy UX.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final optimistic = ChatMessage(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      jobId: jobId,
      senderId: _myUserId,
      senderName: 'Me',
      sentByMe: true,
      text: text.trim(),
      sentAtUtc: DateTime.now().toUtc(),
    );

    state = state.copyWith(messages: [...state.messages, optimistic]);

    try {
      if (_hubReady) {
        await _repo.sendMessageViaHub(jobId, text.trim());
      } else {
        await _repo.sendMessageViaRest(jobId, text.trim());
      }
    } catch (e) {
      state = state.copyWith(error: 'Send failed: ${e.toString()}');
    }
  }

  /// Load older messages (scroll-back). Prepends them to the top of the list.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.oldestId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final result = await _repo.getMessages(jobId, beforeId: state.oldestId);
      final older = result.messages.reversed.toList();
      state = state.copyWith(
        messages: [...older, ...state.messages],
        hasMore: result.hasMore,
        oldestId: result.oldestId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  @override
  void dispose() {
    _hubSub?.cancel();
    _repo.leaveJob(jobId);
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final chatNotifierProvider = StateNotifierProvider.autoDispose
    .family<ChatNotifier, ChatState, String>((ref, jobId) {
  final repo = ref.watch(chatRepositoryProvider);
  
  // Create a placeholder notifier that will initialize itself asynchronously
  final notifier = ChatNotifier(
    jobId: jobId,
    repo: repo,
    myUserId: '', // Will be updated
  );

  // Asynchronously grab user ID from JWT and then init the hub
  Future.microtask(() async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'jwt_token');
    String userId = '';
    
    if (token != null) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final decoded = utf8.decode(base64Url.decode(normalized));
          final map = json.decode(decoded);
          userId = map['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier']?.toString() 
              ?? map['nameid']?.toString() 
              ?? '';
        }
      } catch (_) {}
    }
    
    // Update the internal user ID and initialize
    notifier._myUserId = userId;
    
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5000');
    await notifier.init(baseUrl);
  });

  return notifier;
});
