// Chat unread badge state for the v2 shell (migration plan 3.1, D-1).
//
// Aggregates `ConversationSummary.unreadCount` from GET /api/chat/conversations
// (the same source the v1 inbox uses) into one number for the dock badge.
// This is presentation-layer state only: it reads the existing
// [chatRepositoryProvider] and never mutates data.
//
// The shell refreshes it whenever the current location changes (i.e. every
// navigation rebuilds the shell), and the v2 messages list refreshes it after
// a thread is popped, since reading a thread clears its unread count.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/chat_reviews_repository.dart' show ChatRepository;
import '../../viewmodels/jobs_viewmodel.dart';

class ChatUnreadNotifier extends StateNotifier<AsyncValue<int>> {
  ChatUnreadNotifier(this._repo) : super(const AsyncValue.data(0));

  final ChatRepository _repo;

  /// Total unread messages across conversations. Failures surface as
  /// [AsyncValue.error]; the dock renders no badge for them (a missing badge
  /// must never read as "no unread" lies — the inbox still shows truth).
  Future<void> refresh() async {
    state = const AsyncLoading<int>();
    try {
      final conversations = await _repo.getConversations();
      final total = conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
      state = AsyncValue.data(total);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final chatUnreadProvider =
    StateNotifierProvider<ChatUnreadNotifier, AsyncValue<int>>((ref) {
      return ChatUnreadNotifier(ref.watch(chatRepositoryProvider));
    });
