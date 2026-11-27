// ThMessagesListScreen: v2 messages inbox (migration plan 3.3, id
// `messages_list` — no v2 mockup, tokens-only composition per D-4).
//
// Hand-owned port of views/chat/messages_list_screen.dart +
// ConversationTile. Same data flow (GET /api/chat/conversations via
// chatRepositoryProvider), same truthfulness rules (real preview, real
// unread count, 'No messages yet' for empty threads), same reload-on-return
// after reading a thread, same wide master-detail behaviour (≥744px), same
// row semantics ('$name, $jobTitle[, N unread messages]').
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'th_tab_app_bar.dart';
import '../feedback/th_state_view.dart';
import 'chat_unread_provider.dart';
import 'th_shell.dart' show kThBreakpointMasterDetail;
import '../../viewmodels/theme_mode_viewmodel.dart';
import 'chat_screen.dart';

/// Localized inbox timestamp: today → h:mm a, yesterday → "Yesterday",
/// this week → weekday, older → d/M. UTC is converted to the device zone.
String thConversationTimeLabel(DateTime sentAtUtc) {
  final local = sentAtUtc.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return DateFormat('h:mm a').format(local);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat('E').format(local);
  return DateFormat('d/M').format(local);
}

class ThMessagesListScreen extends ConsumerStatefulWidget {
  const ThMessagesListScreen({super.key});

  @override
  ConsumerState<ThMessagesListScreen> createState() =>
      _ThMessagesListScreenState();
}

class _ThMessagesListScreenState extends ConsumerState<ThMessagesListScreen> {
  bool _loading = true;
  String? _error;
  List<ConversationSummary> _conversations = const [];
  String? _selectedJobId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summaries = await ref
          .read(chatRepositoryProvider)
          .getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = summaries;
        _loading = false;
      });
      // Keep the dock badge in sync with the inbox.
      if (mounted) {
        ref.read(chatUnreadProvider.notifier).refresh();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load conversations.';
        _loading = false;
      });
    }
  }

  Future<void> _open(String jobId) async {
    // Reload on return — reading the thread clears its unread badge.
    await context.push('/chat/$jobId');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          final c = context.th;
          final appBar = ThTabAppBar(title: 'Messages');

          if (_loading && _conversations.isEmpty) {
            return Scaffold(
              backgroundColor: c.paper,
              appBar: appBar,
              body: const Center(child: ThStateView.loading()),
            );
          }

          if (_error != null && _conversations.isEmpty) {
            return Scaffold(
              backgroundColor: c.paper,
              appBar: appBar,
              body: Center(
                child: ThStateView.error(message: _error!, onRetry: _load),
              ),
            );
          }

          if (_conversations.isEmpty) {
            // E-no-messages (v1.6.2 frames-states.html) — designed empty state.
            return Scaffold(
              backgroundColor: c.paper,
              appBar: appBar,
              body: Center(child: ThStateView.preset(ThStatePreset.noMessages)),
            );
          }

          return Scaffold(
            backgroundColor: c.paper,
            appBar: appBar,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final isWide =
                    constraints.maxWidth >= kThBreakpointMasterDetail;

                final masterList = RefreshIndicator(
                  color: c.brand,
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // Card inbox: one card per conversation, spaced by the
                    // gutter rhythm used on the other tab screens.
                    padding: EdgeInsets.fromLTRB(
                      Sizes.gutter,
                      Space.s2,
                      Sizes.gutter,
                      thDockClearance(context),
                    ),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Space.s2_5),
                    itemBuilder: (_, i) {
                      final conversation = _conversations[i];
                      return _ThConversationTile(
                        conversation: conversation,
                        selected:
                            isWide && _selectedJobId == conversation.jobId,
                        onTap: isWide
                            ? () => setState(
                                () => _selectedJobId = conversation.jobId,
                              )
                            : () => _open(conversation.jobId),
                      );
                    },
                  ),
                );

                final detailPanel = _selectedJobId != null
                    ? ThChatScreen(
                        key: ValueKey('chat_$_selectedJobId'),
                        jobId: _selectedJobId!,
                        embedded: true,
                      )
                    : null;

                if (!isWide) return masterList;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: masterList),
                    VerticalDivider(width: 1, color: c.line),
                    Expanded(
                      child: detailPanel ?? const _ThMessagesEmptyDetail(),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ThMessagesEmptyDetail extends StatelessWidget {
  const _ThMessagesEmptyDetail();

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.s4,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: c.textSoft,
            ),
            Text(
              'Select a conversation',
              style: THType.title.copyWith(
                fontWeight: FW.semibold,
                color: c.text,
              ),
            ),
            Text(
              'Choose a chat from the left panel to view messages.',
              textAlign: TextAlign.center,
              style: THType.body.copyWith(color: c.textSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inbox row — participant-first: the counterparty's name is the title and
/// the job is the subtitle. Preview is the real last message;
/// [ConversationSummary.unreadCount] drives a real badge, never an invented
/// dot. Semantics contract carried over from v1 ConversationTile.
class _ThConversationTile extends StatelessWidget {
  final ConversationSummary conversation;
  final VoidCallback onTap;
  final bool selected;

  const _ThConversationTile({
    required this.conversation,
    required this.onTap,
    this.selected = false,
  });

  static String _preview(ConversationSummary c) {
    final text = c.lastMessage;
    if (text == null || text.isEmpty) return 'No messages yet';
    if (c.lastMessageMine) return 'You: $text';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final conversation = this.conversation;
    final name = conversation.otherFirstName.isNotEmpty
        ? conversation.otherFirstName
        : 'Conversation';
    final hasUnread = conversation.unreadCount > 0;

    final noMessages = conversation.lastMessage == null;
    final initial = conversation.otherFirstName.isNotEmpty
        ? conversation.otherFirstName[0].toUpperCase()
        : conversation.jobTitle.isNotEmpty
        ? conversation.jobTitle[0].toUpperCase()
        : '?';

    return Semantics(
      label: hasUnread
          ? '$name, ${conversation.jobTitle}, ${conversation.unreadCount} unread messages'
          : '$name, ${conversation.jobTitle}',
      button: true,
      child: Material(
        color: selected ? c.tintBrand : c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(Space.s3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(
                color: selected
                    ? c.brand
                    : hasUnread
                    ? c.accent
                    : c.line,
                width: hasUnread || selected ? Sizes.borderStrong : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.s3,
              children: [
                THAvatar(initial, size: THAvatarSize.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Space.s1,
                    children: [
                      Row(
                        spacing: Space.s2,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: THType.title.copyWith(
                                fontWeight: FW.semibold,
                                color: c.text,
                              ),
                            ),
                          ),
                          if (conversation.lastMessageAtUtc != null)
                            Text(
                              thConversationTimeLabel(
                                conversation.lastMessageAtUtc!,
                              ),
                              style: THType.meta.copyWith(
                                fontSize: THType.compact.fontSize,
                                color: hasUnread ? c.accentText : c.textSoft,
                              ),
                            ),
                        ],
                      ),
                      // The job is what tells threads apart, so it gets its
                      // own marked line rather than a faint subtitle.
                      Row(
                        spacing: Space.s1,
                        children: [
                          Icon(
                            Icons.work_outline_rounded,
                            size: THType.meta.fontSize,
                            color: c.textBrand,
                          ),
                          Expanded(
                            child: Text(
                              conversation.jobTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: THType.meta.copyWith(
                                fontWeight: FW.medium,
                                color: c.textBrand,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        spacing: Space.s2,
                        children: [
                          Expanded(
                            child: Text(
                              _preview(conversation),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: THType.body.copyWith(
                                fontSize: THType.meta.fontSize,
                                fontWeight: hasUnread
                                    ? FW.semibold
                                    : FW.regular,
                                color: noMessages ? c.textSoft : c.text,
                                fontStyle: noMessages
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                          if (conversation.status == 'Disputed')
                            Icon(
                              Icons.warning_amber_rounded,
                              size: Sizes.icon,
                              color: c.danger,
                            ),
                          // The unread count is the server's, so it shows
                          // even when the last message is mine (earlier
                          // replies can still be unread). The 'You:' prefix
                          // already marks an outgoing preview.
                          if (hasUnread)
                            THBadge(
                              conversation.unreadCount > 99
                                  ? '99+'
                                  : '${conversation.unreadCount}',
                              kind: THBadgeKind.accent,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
