// ThChatScreen: v2 job chat (migration plan 3.3, id `chat`).
//
// Hand-owned port of views/chat/chat_screen.dart + the pieces of
// views/widgets/chat_widgets.dart it composes (bubbles, composer, quick
// replies, date separators, status pill). Behavioural parity checklist
// (every action routes to the same viewmodels/repositories as v1):
//   • participant-first header (contact endpoint → message sender → job title)
//   • Call only when the server authorized a number (Booked+)
//   • Schedule action at Booked/InProgress → v1 ScheduleSheet (transitional
//     coexistence, like THNotice → v1 host; the sheet moves to v2 with the
//     job-detail screens in a later phase)
//   • safety menu (report abuse / block user) via profileRepository
//   • quick replies populate the composer, never auto-send
//   • send clears the field first, goes hub-first via ChatNotifier.sendMessage
//   • truthful failed-send retry ('Not sent — tap to retry')
//   • locked composer for Completed/Cancelled/Disputed (ChatService.IsChatOpenAsync)
//   • status pill ('Step N of 4 · …'), chat-closed banner, date separators
//   • scroll-to-bottom on new messages / first load; loadMore at the top
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../network/api_error.dart';
import '../../network/external_launcher.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/schedule_sheet.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import '../feedback/th_state_view.dart';
import 'th_shell.dart' show kThMaxContentWidth;
import '../../viewmodels/theme_mode_viewmodel.dart';

/// Role-appropriate quick replies — populate the composer for editing,
/// never auto-send.
const _homeownerReplies = [
  'Thanks!',
  'That works for me.',
  'When can you start?',
  'Could you send a receipt?',
];
const _tradieReplies = [
  'Thanks!',
  "I'm on my way.",
  'Running a bit late — sorry!',
  'All done — sending photos now.',
];

/// Statuses where the backend serves the participant contact (Booked+).
const _contactableStatuses = {
  'Booked',
  'InProgress',
  'AwaitingConfirmation',
  'Completed',
  'Disputed',
};

/// Mirrors ChatService.IsChatOpenAsync — new messages are rejected
/// server-side for Completed, Cancelled and Disputed jobs.
const _lockedStatuses = {'Completed', 'Cancelled', 'Disputed'};

class ThChatScreen extends ConsumerStatefulWidget {
  final String jobId;
  final bool embedded;

  const ThChatScreen({super.key, required this.jobId, this.embedded = false});

  @override
  ConsumerState<ThChatScreen> createState() => _ThChatScreenState();
}

class _ThChatScreenState extends ConsumerState<ThChatScreen> {
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();
  final _scrollCtrl = ScrollController();

  JobContact? _contact;
  bool _contactFetched = false;
  Job? _fetchedJob;
  bool _jobFetchAttempted = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    Future.microtask(_fetchMissingJob);
  }

  /// Jump to the newest message. Called after the first history load and
  /// whenever a new message is appended.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: THMotion.duration(context, THMotion.chatScroll),
        curve: THMotion.curve(context, THMotion.chatCurve),
      );
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels <=
        _scrollCtrl.position.minScrollExtent + 50) {
      ref.read(chatNotifierProvider(widget.jobId).notifier).loadMore();
    }
  }

  /// Deep links can land here with the jobs list not loaded — fetch the job
  /// once so the header/lock state is truthful instead of blank.
  Future<void> _fetchMissingJob() async {
    if (_jobFetchAttempted) return;
    _jobFetchAttempted = true;
    final jobs = ref.read(jobsViewModelProvider).jobs;
    if (jobs.any((j) => j.id == widget.jobId)) return;
    try {
      final job = await ref
          .read(jobsRepositoryProvider)
          .getJobById(widget.jobId);
      if (mounted) setState(() => _fetchedJob = job);
    } catch (_) {
      // Leave the header on its job-title/'Chat' fallbacks.
    }
  }

  /// Fetch the participant contact once the job reaches a contactable status.
  /// The endpoint is NotFound before Booked — nothing is shown then.
  Future<void> _fetchContact(String status) async {
    if (_contactFetched || !_contactableStatuses.contains(status)) return;
    _contactFetched = true;
    final contact = await ref
        .read(jobsRepositoryProvider)
        .getJobContact(widget.jobId);
    if (mounted) setState(() => _contact = contact);
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    await ref
        .read(chatNotifierProvider(widget.jobId).notifier)
        .sendMessage(text);
  }

  Future<void> _call() async {
    final phone = _contact?.phoneNumber?.trim();
    if (phone == null || phone.isEmpty) return;
    final ok = await ref.read(externalLauncherProvider).callPhone(phone);
    if (!ok && mounted) {
      THNotice.warning(context, NoticeCopy.noCallApp);
    }
  }

  /// P8-02: the "other party" is the matched tradie when known; otherwise the
  /// report/block still works from the public profile screen.
  Future<void> _onSafetyAction(
    BuildContext context,
    String action,
    Job? job,
  ) async {
    final otherId = job?.matchedTradieId;
    if (otherId == null || otherId.isEmpty) {
      if (!context.mounted) return;
      THNotice.info(context, NoticeCopy.noOtherUser);
      return;
    }
    final repo = ref.read(profileRepositoryProvider);
    try {
      if (action == 'block') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Block user?'),
            content: const Text(
              'You will no longer be matched with this user.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Block'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        await repo.blockUser(otherId);
        if (!context.mounted) return;
        THNotice.info(context, NoticeCopy.userBlocked);
      } else {
        final reasonCtrl = TextEditingController();
        final reason = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Report abuse'),
            content: TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                hintText: 'What happened? (optional)',
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, reasonCtrl.text.trim()),
                child: const Text('Report'),
              ),
            ],
          ),
        );
        if (reason == null) return;
        await repo.reportUser(otherId, reason: reason);
        if (!context.mounted) return;
        THNotice.success(context, NoticeCopy.reportSent);
      }
    } catch (e) {
      if (!context.mounted) return;
      final msg = e is DioException
          ? friendlyDioError(e, tag: 'ChatScreen.safety')
          : e.toString();
      THNotice.errorDynamic(context, msg);
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider(widget.jobId));
    final jobsState = ref.watch(jobsViewModelProvider);
    final listed = jobsState.jobs.cast<Job?>().firstWhere(
      (j) => j?.id == widget.jobId,
      orElse: () => null,
    );
    final job = listed ?? _fetchedJob;
    final status = job?.status ?? '';

    // Fetch the participant contact when the job is (or becomes) contactable.
    if (status.isNotEmpty) {
      Future.microtask(() => _fetchContact(status));
    }

    // Locked exactly per ChatService.IsChatOpenAsync.
    final isChatLocked = _lockedStatuses.contains(status);

    // Participant-first header: the counterparty's first name when the
    // authorized contact endpoint serves it, else the other party's name
    // from their messages, else the job title.
    final otherName = _contact?.firstName.trim() ?? '';
    final senderName = chatState.messages
        .where((m) => !m.sentByMe && m.senderName.isNotEmpty)
        .map((m) => m.senderName.trim())
        .firstOrNull;
    final participant = otherName.isNotEmpty ? otherName : (senderName ?? '');
    final title = participant.isNotEmpty ? participant : (job?.title ?? 'Chat');
    final subtitle = participant.isNotEmpty ? job?.title : null;

    final role = ref.watch(profileViewModelProvider).profile?['role'];
    final quickReplies = role == 1 ? _tradieReplies : _homeownerReplies;
    final hasPhone = _contact?.phoneNumber?.trim().isNotEmpty == true;

    // Auto-scroll to bottom when new messages arrive.
    ref.listen(chatNotifierProvider(widget.jobId), (prev, next) {
      if (prev == null) return;
      if (next.messages.length > prev.messages.length) {
        _scrollToBottom();
      }
      // Also scroll on first load.
      if (prev.isLoading && !next.isLoading && next.messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    // Verified: we treat InProgress / Booked / Completed as verified contexts.
    final isVerified = _contactableStatuses.contains(status);

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          final c = context.th;
          return Scaffold(
            backgroundColor: c.paper,
            appBar: THAppBar(
              title: title,
              subtitle: subtitle,
              showBack: !widget.embedded,
              leading: _ThChatAvatar(
                initials: participant.isNotEmpty
                    ? participant[0].toUpperCase()
                    : '?',
                verified: isVerified,
              ),
              actions: [
                if (status == 'Booked' || status == 'InProgress')
                  THIconButton(
                    icon: Icons.calendar_month_outlined,
                    semanticLabel: 'Schedule',
                    onPressed: () =>
                        ScheduleSheet.show(context, jobId: widget.jobId),
                  ),
                // Call is shown only when the server authorized a real number.
                if (hasPhone)
                  THIconButton(
                    icon: Icons.phone_outlined,
                    semanticLabel: 'Call',
                    onPressed: _call,
                  ),
                // P8-02: safety menu — report abuse or block the other party.
                PopupMenuButton<String>(
                  tooltip: 'More options',
                  icon: Icon(Icons.more_vert, color: c.textSoft),
                  onSelected: (v) => _onSafetyAction(context, v, job),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'report', child: Text('Report abuse')),
                    PopupMenuItem(value: 'block', child: Text('Block user')),
                  ],
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  // ── Status pill below the header ────────────────────────
                  if (status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Sizes.gutter,
                        Space.s2_5,
                        Sizes.gutter,
                        Space.s1,
                      ),
                      child: Center(
                        child: THBadge(
                          _statusLabel(status),
                          kind: status == 'Disputed'
                              ? THBadgeKind.danger
                              : THBadgeKind.brand,
                          icon: status == 'Disputed'
                              ? Icons.warning_amber_rounded
                              : Icons.access_time_rounded,
                        ),
                      ),
                    ),
                  // ── Chat-closed banner ──────────────────────────────────
                  if (isChatLocked)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Sizes.gutter,
                        vertical: Space.s2_5,
                      ),
                      color: c.surfaceAlt,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: Space.s2,
                        children: [
                          Icon(Icons.lock_outline, size: 16, color: c.textSoft),
                          Flexible(
                            child: Text(
                              switch (status) {
                                'Completed' =>
                                  'Chat is closed — job completed.',
                                'Disputed' => 'Chat is closed — job disputed.',
                                _ => 'Chat is closed — job cancelled.',
                              },
                              textAlign: TextAlign.center,
                              style: THType.meta.copyWith(color: c.textSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // ── Messages list ───────────────────────────────────────
                  Expanded(
                    child: chatState.isLoading && chatState.messages.isEmpty
                        ? Center(
                            child: CircularProgressIndicator(color: c.brand),
                          )
                        : chatState.loadError != null &&
                              chatState.messages.isEmpty
                        ? Center(
                            child: ThStateView.error(
                              message: 'Could not load messages.',
                              onRetry: () => ref
                                  .read(
                                    chatNotifierProvider(widget.jobId).notifier,
                                  )
                                  .reload(),
                            ),
                          )
                        : Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: kThMaxContentWidth,
                              ),
                              child: ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.all(Space.s4),
                                itemCount:
                                    _buildMessageItems(chatState.messages)
                                        .length +
                                    (chatState.hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (chatState.hasMore && index == 0) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(Space.s2),
                                        child: SizedBox.square(
                                          dimension: Sizes.iconLg,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: c.brand,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final offset = chatState.hasMore ? 1 : 0;
                                  final item = _buildMessageItems(
                                    chatState.messages,
                                  )[index - offset];
                                  if (item is _DateSeparatorItem) {
                                    return _ThChatDateSeparator(
                                      timestampUtc: item.timestamp,
                                    );
                                  }
                                  final mi = item as _MessageItem;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: mi.isGrouped
                                          ? Space.s1
                                          : Space.s3,
                                    ),
                                    child: _ThChatBubble(
                                      message: mi.message,
                                      isGrouped: mi.isGrouped,
                                      failed: chatState.failedIds.contains(
                                        mi.message.id,
                                      ),
                                      onRetry: () => ref
                                          .read(
                                            chatNotifierProvider(widget.jobId)
                                                .notifier,
                                          )
                                          .retryMessage(mi.message.id),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            // ── Input bar — extends background behind home indicator ─────
            bottomNavigationBar: Container(
              color: c.surfaceAlt,
              padding: EdgeInsets.fromLTRB(
                Space.s3,
                Space.s2,
                Space.s3,
                MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom +
                    Space.s2,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 1.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kThMaxContentWidth,
                  ),
                  child: isChatLocked
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Space.s2,
                            horizontal: Space.s1,
                          ),
                          child: Text(
                            'Messaging is disabled for this job.',
                            textAlign: TextAlign.center,
                            style: THType.meta.copyWith(color: c.textSoft),
                          ),
                        )
                      : _ThChatComposer(
                          controller: _inputCtrl,
                          focusNode: _inputFocus,
                          onSend: _send,
                          quickReplies: quickReplies,
                          hintText: participant.isNotEmpty
                              ? 'Message $participant…'
                              : null,
                          onAttach: () => THNotice.info(
                            context,
                            NoticeCopy.photoUnavailable,
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Message list helpers ──────────────────────────────────────────────────────

/// Sealed item types for the message list — either a date separator or a bubble.
sealed class _ListItem {}

class _DateSeparatorItem extends _ListItem {
  final DateTime timestamp;
  _DateSeparatorItem(this.timestamp);
}

class _MessageItem extends _ListItem {
  final ChatMessage message;
  final bool isGrouped;
  _MessageItem(this.message, {this.isGrouped = false});
}

/// Builds the interleaved list of separators and message items.
/// A separator is inserted:
///   • Before the first message
///   • When > 5 minutes pass between consecutive messages from different sessions
/// A bubble is "grouped" (no sender name, tighter gap) when:
///   • Same sender as the previous message AND
///   • Within 60 seconds
List<_ListItem> _buildMessageItems(List<ChatMessage> messages) {
  final items = <_ListItem>[];
  DateTime? lastSeparatorTime;
  ChatMessage? prev;

  for (final m in messages) {
    // Insert separator if this is the first message or > 5 min gap.
    final needsSeparator =
        lastSeparatorTime == null ||
        m.sentAtUtc.difference(lastSeparatorTime).abs().inMinutes >= 5;
    if (needsSeparator) {
      items.add(_DateSeparatorItem(m.sentAtUtc));
      lastSeparatorTime = m.sentAtUtc;
    }

    // Group with previous if same sender and < 60 seconds apart.
    final isGrouped =
        prev != null &&
        prev.sentByMe == m.sentByMe &&
        m.sentAtUtc.difference(prev.sentAtUtc).inSeconds.abs() < 60 &&
        !needsSeparator;

    items.add(_MessageItem(m, isGrouped: isGrouped));
    prev = m;
  }
  return items;
}

/// Human-readable step label from raw status string (v1 _ChatStatusPill).
String _statusLabel(String status) => switch (status) {
  'Requested' => 'Step 1 of 4 · Requested',
  'Booked' => 'Step 2 of 4 · Booked',
  'InProgress' || 'In Progress' => 'Step 3 of 4 · In progress',
  'AwaitingConfirmation' => 'Step 4 of 4 · Awaiting confirmation',
  'Completed' => 'Step 4 of 4 · Completed',
  'Cancelled' => 'Cancelled',
  'Disputed' => 'Disputed',
  _ => status,
};

/// Avatar with an optional green verified badge (needs-design: same concept
/// as the v1 _ChatAvatar, TH tokens).
class _ThChatAvatar extends StatelessWidget {
  final String initials;
  final bool verified;

  const _ThChatAvatar({required this.initials, this.verified = false});

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return THAvatar(initials, size: THAvatarSize.sm).verified(verified, c);
  }
}

extension on THAvatar {
  Widget verified(bool on, THColors c) {
    if (!on) return this;
    return SizedBox(
      width: Sizes.avatarSm + Space.s1,
      height: Sizes.avatarSm + Space.s1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          this,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: Space.s4,
              height: Space.s4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.success,
                border: Border.all(color: c.paper, width: 1.5),
              ),
              child: Icon(Icons.check, size: Sizes.iconSm, color: c.onBrand),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single chat bubble: sender name (incoming, first in a group), body,
/// localized time — or the truthful "Not sent — tap to retry" state wired to
/// [onRetry]. TH-token repaint of v1 ChatBubble.
class _ThChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool failed;
  final bool isGrouped;
  final VoidCallback? onRetry;

  const _ThChatBubble({
    required this.message,
    this.failed = false,
    this.isGrouped = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final m = message;

    return Align(
      alignment: m.sentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: m.sentByMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          spacing: Space.s1,
          children: [
            // Sender name (incoming only, first in a group)
            if (!m.sentByMe && m.senderName.isNotEmpty && !isGrouped)
              Text(
                m.senderName,
                style: THType.meta.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.textBrand,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.s4,
                vertical: Space.s3,
              ),
              decoration: BoxDecoration(
                color: m.sentByMe ? c.brand : c.surface,
                border: m.sentByMe ? null : Border.all(color: c.line),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(Radii.chatBubble),
                  topRight: const Radius.circular(Radii.chatBubble),
                  bottomLeft: Radius.circular(
                    m.sentByMe ? Radii.chatBubble : Radii.chatBubbleTail,
                  ),
                  bottomRight: Radius.circular(
                    m.sentByMe ? Radii.chatBubbleTail : Radii.chatBubble,
                  ),
                ),
              ),
              child: Text(
                m.text ?? '',
                style: THType.body.copyWith(
                  height: 1.45,
                  color: m.sentByMe ? c.onBrand : c.text,
                ),
              ),
            ),
            // Timestamp or failed state
            if (failed)
              InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(Radii.control),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.s1,
                    vertical: Space.s3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: Space.s1,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: Sizes.iconSm,
                        color: c.danger,
                      ),
                      Flexible(
                        child: Text(
                          'Not sent — tap to retry',
                          style: THType.meta.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.only(
                  left: m.sentByMe ? 0 : Space.s2,
                  right: m.sentByMe ? Space.s2 : 0,
                ),
                child: Text(
                  DateFormat('h:mm a').format(m.sentAtUtc.toLocal()),
                  style: THType.meta.copyWith(
                    fontSize: THType.compact.fontSize,
                    color: c.textSoft,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Centred timestamp divider between message groups — e.g. "Today 1:47 pm".
class _ThChatDateSeparator extends StatelessWidget {
  final DateTime timestampUtc;

  const _ThChatDateSeparator({required this.timestampUtc});

  String _label() {
    final local = timestampUtc.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    final time = DateFormat('h:mm a').format(local);
    if (diff <= 0) return 'Today $time';
    if (diff == 1) return 'Yesterday $time';
    if (diff < 7) return '${DateFormat('EEEE').format(local)} $time';
    return DateFormat('d MMM').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s4),
      child: Row(
        spacing: Space.s3,
        children: [
          Expanded(child: Container(height: 1, color: c.line)),
          Flexible(
            flex: 4,
            child: Text(
              _label(),
              textAlign: TextAlign.center,
              softWrap: true,
              style: THType.meta.copyWith(
                fontWeight: FontWeight.w500,
                color: c.textSoft,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: c.line)),
        ],
      ),
    );
  }
}

/// Message composer: optional role-appropriate [quickReplies] that populate
/// the field for editing (never auto-send), an attach action, the text field
/// and a ≥48px send button. TH-token repaint of v1 ChatComposer.
class _ThChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final List<String> quickReplies;
  final String? hintText;

  const _ThChatComposer({
    required this.controller,
    required this.onSend,
    this.focusNode,
    this.onAttach,
    this.quickReplies = const [],
    this.hintText,
  });

  void _applyQuickReply(String text) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    focusNode?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.s2,
      children: [
        // ── Quick-reply chips ───────────────────────────────────────────
        if (quickReplies.isNotEmpty)
          SizedBox(
            height: Sizes.quickReplyHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: Space.s1),
              itemCount: quickReplies.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.s2),
              itemBuilder: (_, i) {
                final reply = quickReplies[i];
                return Semantics(
                  button: true,
                  label: reply,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => _applyQuickReply(reply),
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.s4,
                        vertical: Space.s1,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        border: Border.all(color: c.line),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Sizes.quickReplyWidth,
                        ),
                        child: Text(
                          reply,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: THType.button.copyWith(
                            fontSize: THType.meta.fontSize,
                            fontWeight: FontWeight.w500,
                            color: c.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // ── Input row ───────────────────────────────────────────────────
        Row(
          spacing: Space.s2_5,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Attach / image button
            if (onAttach != null)
              THIconButton(
                icon: Icons.image_outlined,
                semanticLabel: 'Attach photo',
                onPressed: onAttach,
              ),
            // Text field — pill shaped
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: Sizes.input),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: c.line),
                ),
                padding: const EdgeInsets.symmetric(horizontal: Space.s5),
                alignment: Alignment.center,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  style: THType.body.copyWith(color: c.text),
                  decoration: InputDecoration(
                    hintText: hintText ?? 'Message…',
                    hintStyle: THType.body.copyWith(color: c.textSoft),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isCollapsed: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),

            // Send button — accent circle with arrow icon
            Tooltip(
              message: 'Send message',
              child: GestureDetector(
                key: const Key('send_message_button'),
                onTap: onSend,
                child: Container(
                  width: Sizes.fab,
                  height: Sizes.fab,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.accent,
                    boxShadow: [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: c.onAccent,
                    size: Sizes.iconLg,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
