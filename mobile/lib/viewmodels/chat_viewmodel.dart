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

  /// Ids of optimistic local messages whose send failed — shown with a retry
  /// affordance until [ChatNotifier.retryMessage] succeeds or the user leaves.
  final Set<String> failedIds;

  /// Set only when the initial history load fails — rendered as a retryable
  /// error rather than a misleading "no messages yet" list.
  final String? loadError;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = false,
    this.oldestId,
    this.failedIds = const {},
    this.loadError,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? hasMore,
    int? oldestId,
    Set<String>? failedIds,
    String? loadError,
    bool clearLoadError = false,
  }) => ChatState(
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    hasMore: hasMore ?? this.hasMore,
    oldestId: oldestId ?? this.oldestId,
    failedIds: failedIds ?? this.failedIds,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
  );
}

// ── ChatNotifier ──────────────────────────────────────────────────────────────

/// ViewModel for the Chat screen (M3-07, V15-16).
///
/// Manages message list, hub subscription, pagination, send retry and
/// reconnect reconciliation. Connects to ChatHub on [init], exposes
/// [sendMessage], [retryMessage] and [loadMore].
class ChatNotifier extends StateNotifier<ChatState> {
  final String jobId;
  final ChatRepository _repo;
  String _myUserId;

  StreamSubscription<ChatMessage>? _hubSub;
  StreamSubscription<void>? _reconnectSub;
  bool _hubReady = false;

  ChatNotifier({
    required this.jobId,
    required ChatRepository repo,
    required String myUserId,
  }) : _repo = repo,
       _myUserId = myUserId,
       super(const ChatState());

  /// Call once when the chat screen mounts.
  Future<void> init(String baseUrl) async {
    state = state.copyWith(isLoading: true, clearLoadError: true);

    // Start REST history load in parallel with hub connect.
    await Future.wait([_loadInitialHistory(), _connectHub(baseUrl)]);

    // Only now is the hub known-good (or not) — mark incoming unread once.
    _markIncomingRead(state.messages);
  }

  /// Retry after a failed initial load.
  Future<void> reload() => _loadInitialHistory();

  /// Called by the provider once the JWT user id is decoded. Re-tags server
  /// rows — the wire DTO carries no sentByMe flag, so own messages must be
  /// recognised by sender id (otherwise they'd render as incoming).
  void updateUserId(String userId) {
    _myUserId = userId;
    if (state.messages.isEmpty) return;
    state = state.copyWith(messages: state.messages.map(_tag).toList());
  }

  ChatMessage _tag(ChatMessage m) {
    if (m.sentByMe || _myUserId.isEmpty || m.senderId != _myUserId) return m;
    return ChatMessage(
      id: m.id,
      jobId: m.jobId,
      senderId: m.senderId,
      senderName: m.senderName,
      sentByMe: true,
      text: m.text,
      imageUrl: m.imageUrl,
      sentAtUtc: m.sentAtUtc,
      readAtUtc: m.readAtUtc,
    );
  }

  Future<void> _loadInitialHistory() async {
    try {
      final result = await _repo.getMessages(jobId);
      // Messages come newest-first from server; reverse so oldest is at top.
      final reversed = result.messages.reversed.map(_tag).toList();
      state = state.copyWith(
        messages: reversed,
        hasMore: result.hasMore,
        oldestId: result.oldestId,
        isLoading: false,
        clearLoadError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, loadError: e.toString());
    }
  }

  Future<void> _connectHub(String baseUrl) async {
    try {
      await _repo.connectHub(baseUrl);
      await _repo.joinJob(jobId);
      _hubReady = true;

      _hubSub = _repo.onNewMessage.listen(_onHubMessage);
      _reconnectSub = _repo.onReconnected.listen((_) => _onReconnected());
    } catch (_) {
      // Hub failure is non-fatal — REST history and REST send still work.
    }
  }

  void _onHubMessage(ChatMessage msg) {
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

    if (state.messages.any((m) => m.id == tagged.id)) {
      // Already have the server row (e.g. reconcile raced the broadcast).
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == tagged.id ? tagged : m)
            .toList(),
      );
      return;
    }

    if (tagged.sentByMe) {
      // Server echo of our own send: swap the matching optimistic bubble for
      // the confirmed row instead of appending a duplicate.
      final idx = state.messages.indexWhere(
        (m) => m.id.startsWith('local-') && m.sentByMe && m.text == tagged.text,
      );
      if (idx >= 0) {
        final localId = state.messages[idx].id;
        final updated = [...state.messages];
        updated[idx] = tagged;
        state = state.copyWith(
          messages: _sorted(updated),
          failedIds: {...state.failedIds}..remove(localId),
        );
        return;
      }
    }

    state = state.copyWith(messages: [...state.messages, tagged]);
    if (!tagged.sentByMe) _markIncomingRead([tagged]);
  }

  /// Server-side group membership does not survive reconnect: re-join the job
  /// group and merge the newest history page so messages missed while
  /// disconnected appear exactly once (dedup by id; server rows win).
  Future<void> _onReconnected() async {
    try {
      await _repo.joinJob(jobId);
      _hubReady = true;
    } catch (_) {
      _hubReady = false;
      return;
    }
    await _reconcile();
  }

  Future<void> _reconcile() async {
    try {
      final result = await _repo.getMessages(jobId);
      final byId = <String, ChatMessage>{
        for (final m in state.messages) m.id: m,
      };
      for (final m in result.messages) {
        // Server row wins — refreshes content/read state on existing ids and
        // backfills messages that arrived while we were disconnected.
        byId[m.id] = _tag(m);
      }
      state = state.copyWith(messages: _sorted(byId.values.toList()));
      _markIncomingRead(result.messages);
    } catch (_) {
      // Keep the current list; the next event or manual reload retries.
    }
  }

  /// Mark messages from the other party as read (drives the real unread
  /// count in the inbox). Hub-only — a no-op while disconnected. Each
  /// server id is marked at most once; failures release it for a retry.
  final _markedReadIds = <int>{};

  void _markIncomingRead(List<ChatMessage> messages) {
    if (!_hubReady) return;
    for (final m in messages) {
      if (m.senderId == _myUserId || m.readAtUtc != null) continue;
      final id = int.tryParse(m.id);
      if (id == null) continue; // optimistic local row — nothing to mark
      if (!_markedReadIds.add(id)) continue;
      _repo.markRead(jobId, id).catchError((_) {
        _markedReadIds.remove(id);
      });
    }
  }

  /// Send a message. Uses hub when connected, REST as fallback.
  /// Optimistically appends a local bubble immediately for snappy UX; on
  /// failure the bubble is kept and flagged in [ChatState.failedIds].
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final optimistic = ChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      jobId: jobId,
      senderId: _myUserId,
      senderName: 'Me',
      sentByMe: true,
      text: trimmed,
      sentAtUtc: DateTime.now().toUtc(),
    );

    state = state.copyWith(messages: [...state.messages, optimistic]);
    await _deliver(optimistic);
  }

  /// Re-attempt a previously failed optimistic message.
  Future<void> retryMessage(String localId) async {
    final idx = state.messages.indexWhere(
      (m) => m.id == localId && state.failedIds.contains(localId),
    );
    if (idx < 0) return;
    state = state.copyWith(failedIds: {...state.failedIds}..remove(localId));
    await _deliver(state.messages[idx]);
  }

  Future<void> _deliver(ChatMessage local) async {
    try {
      if (_hubReady) {
        await _repo.sendMessageViaHub(jobId, local.text ?? '');
        // The server broadcasts the row back to the group; _onHubMessage
        // swaps the optimistic bubble for it. If the broadcast never arrives
        // the bubble stays (truthfully unconfirmed but sent).
      } else {
        final saved = await _repo.sendMessageViaRest(jobId, local.text ?? '');
        // No group membership when the hub is down, so no echo will arrive —
        // replace the optimistic bubble with the returned server row now.
        final idx = state.messages.indexWhere((m) => m.id == local.id);
        if (idx >= 0) {
          final updated = [...state.messages];
          updated[idx] = ChatMessage(
            id: saved.id,
            jobId: saved.jobId,
            senderId: saved.senderId,
            senderName: saved.senderName,
            sentByMe: true,
            text: saved.text,
            imageUrl: saved.imageUrl,
            sentAtUtc: saved.sentAtUtc,
            readAtUtc: saved.readAtUtc,
          );
          state = state.copyWith(messages: _sorted(updated));
        }
      }
    } catch (_) {
      state = state.copyWith(failedIds: {...state.failedIds, local.id});
    }
  }

  /// Load older messages (scroll-back). Prepends them to the top of the list.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.oldestId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final result = await _repo.getMessages(jobId, beforeId: state.oldestId);
      final older = result.messages.reversed.map(_tag).toList();
      final existing = state.messages.map((m) => m.id).toSet();
      state = state.copyWith(
        messages: [
          ...older.where((m) => !existing.contains(m.id)),
          ...state.messages,
        ],
        hasMore: result.hasMore,
        oldestId: result.oldestId,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Chronological order; server rows ordered by sentAtUtc then numeric id,
  /// optimistic locals settle by their injected timestamp.
  List<ChatMessage> _sorted(List<ChatMessage> messages) {
    final sorted = [...messages];
    sorted.sort((a, b) {
      final t = a.sentAtUtc.compareTo(b.sentAtUtc);
      if (t != 0) return t;
      return (int.tryParse(a.id) ?? 1 << 62).compareTo(
        int.tryParse(b.id) ?? 1 << 62,
      );
    });
    return sorted;
  }

  @override
  void dispose() {
    _hubSub?.cancel();
    _reconnectSub?.cancel();
    _repo.leaveJob(jobId);
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Decode the current user id from the stored JWT. Returns '' when the token
/// is missing or unparseable — callers treat '' as "not yet known" and never
/// match it against sender ids.
Future<String> _decodeUserId(Ref ref) async {
  try {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'jwt_token');
    if (token == null) return '';
    final parts = token.split('.');
    if (parts.length != 3) return '';
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final map = json.decode(decoded);
    return map['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier']
            ?.toString() ??
        map['nameid']?.toString() ??
        '';
  } catch (_) {
    return '';
  }
}

final chatNotifierProvider = StateNotifierProvider.autoDispose
    .family<ChatNotifier, ChatState, String>((ref, jobId) {
      final repo = ref.watch(chatRepositoryProvider);

      final notifier = ChatNotifier(jobId: jobId, repo: repo, myUserId: '');

      Future.microtask(() async {
        // Decode user id first so that hub echoes of our own messages are
        // correctly tagged sentByMe=true before the initial history arrives.
        final userId = await _decodeUserId(ref).catchError((_) => '');
        notifier.updateUserId(userId);
        await notifier.init(resolveBaseUrl());
      });

      return notifier;
    });
