import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marketplace.dart';
import '../../network/api_error.dart';
import '../../network/external_launcher.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_states.dart';
import '../widgets/chat_widgets.dart';
import '../../widgets/schedule_sheet.dart';

/// Job-scoped chat thread (V15-16).
///
/// Participant-first header (name + job subtitle), shared bubbles/composer,
/// role-appropriate quick replies that only populate the field, an authorized
/// Call action (server-issued phone at Booked+ only), truthful failed-send
/// retry, and reconnect reconciliation handled by [ChatNotifier].
class ChatScreen extends ConsumerStatefulWidget {
  final String jobId;
  final bool embedded;

  const ChatScreen({
    super.key,
    required this.jobId,
    this.embedded = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();
  final _scrollCtrl = ScrollController();

  JobContact? _contact;
  bool _contactFetched = false;
  Job? _fetchedJob;
  bool _jobFetchAttempted = false;

  /// Statuses where the backend serves the participant contact (Booked+).
  static const _contactableStatuses = {
    'Booked',
    'InProgress',
    'AwaitingConfirmation',
    'Completed',
    'Disputed',
  };

  /// Mirrors ChatService.IsChatOpenAsync — new messages are rejected
  /// server-side for Completed, Cancelled and Disputed jobs.
  static const _lockedStatuses = {'Completed', 'Cancelled', 'Disputed'};

  /// Role-appropriate quick replies — populate the composer for editing,
  /// never auto-send.
  static const _homeownerReplies = [
    'Thanks!',
    'That works for me.',
    'When can you start?',
    'Could you send a receipt?',
  ];
  static const _tradieReplies = [
    'Thanks!',
    "I'm on my way.",
    'Running a bit late — sorry!',
    'All done — sending photos now.',
  ];

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
        duration: FixoDurations.fast,
        curve: Curves.easeOut,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No app available to make the call.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other user on this job yet.')),
      );
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('User blocked.')));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks — our team will review this report.'),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      final msg = e is DioException
          ? friendlyDioError(e, tag: 'ChatScreen.safety')
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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

    return Scaffold(
      appBar: FixoAppBar(
        title: title,
        subtitle: subtitle,
        showBack: !widget.embedded,
        leading: _ChatAvatar(
          initials: participant.isNotEmpty ? participant[0].toUpperCase() : '?',
          verified: isVerified,
        ),
        actions: [
          if (status == 'Booked' || status == 'InProgress')
            IconButton(
              tooltip: 'Schedule',
              onPressed: () => ScheduleSheet.show(context, jobId: widget.jobId),
              icon: Icon(
                Icons.calendar_month_outlined,
                size: 22,
                color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
              ),
            ),
          // Call is shown only when the server authorized a real number.
          if (hasPhone)
            IconButton(
              tooltip: 'Call',
              onPressed: _call,
              icon: const Icon(
                Icons.phone_outlined,
                size: 22,
                color: DesignTokens.brand500,
              ),
            ),
          // P8-02: safety menu — report abuse or block the other party.
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: Icon(
              Icons.more_vert,
              color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
            ),
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
            // ── Status pill below the header ─────────────────────────────
            if (status.isNotEmpty)
              _ChatStatusPill(status: status, isDark: isDark),
            // ── P5-08: Chat-closed banner ─────────────────────────────────
            if (isChatLocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.s2_5),
                color: isDark
                    ? DesignTokens.paperLineDark.withValues(alpha: Alpha.divider)
                    : DesignTokens.paperLineLight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: Space.s2),
                    Flexible(
                      child: Text(
                        switch (status) {
                          'Completed' => 'Chat is closed — job completed.',
                          'Disputed' => 'Chat is closed — job disputed.',
                          _ => 'Chat is closed — job cancelled.',
                        },
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // ── Messages list ─────────────────────────────────────────────
            Expanded(
              child: chatState.isLoading && chatState.messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : chatState.loadError != null && chatState.messages.isEmpty
                  ? FixoErrorState(
                      message: 'Could not load messages.',
                      onRetry: () => ref
                          .read(chatNotifierProvider(widget.jobId).notifier)
                          .reload(),
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: kMaxContentWidth,
                        ),
                        child: _DottedBackground(
                          isDark: isDark,
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(
                              Space.s4, Space.s4, Space.s4, Space.s3,
                            ),
                            itemCount: _buildMessageItems(chatState.messages).length +
                                (chatState.hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (chatState.hasMore && index == 0) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(Space.s2),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final offset = chatState.hasMore ? 1 : 0;
                              final item = _buildMessageItems(chatState.messages)[index - offset];
                              if (item is _DateSeparatorItem) {
                                return ChatDateSeparator(timestampUtc: item.timestamp);
                              }
                              final mi = item as _MessageItem;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: mi.isGrouped ? Space.s1 : Space.s3,
                                ),
                                child: ChatBubble(
                                  message: mi.message,
                                  isGrouped: mi.isGrouped,
                                  failed: chatState.failedIds.contains(mi.message.id),
                                  onRetry: () => ref
                                      .read(
                                        chatNotifierProvider(widget.jobId).notifier,
                                      )
                                      .retryMessage(mi.message.id),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      // ── Input bar — extends background behind home indicator ───────────
      bottomNavigationBar: Container(
        color: DesignTokens.surfaceCard(isDark),
        padding: EdgeInsets.fromLTRB(Space.s3, Space.s2, Space.s3, MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              8),
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: isChatLocked
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.s2, horizontal: Space.s1),
                    child: Text(
                      'Messaging is disabled for this job.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ChatComposer(
                    controller: _inputCtrl,
                    focusNode: _inputFocus,
                    onSend: _send,
                    quickReplies: quickReplies,
                    hintText: participant.isNotEmpty
                        ? 'Message $participant…'
                        : null,
                    onAttach: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Photo attachments are not available in chat.',
                        ),
                      ),
                    ),
                  ),
          ),
        ),
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
    final needsSeparator = lastSeparatorTime == null ||
        m.sentAtUtc.difference(lastSeparatorTime).abs().inMinutes >= 5;
    if (needsSeparator) {
      items.add(_DateSeparatorItem(m.sentAtUtc));
      lastSeparatorTime = m.sentAtUtc;
    }

    // Group with previous if same sender and < 60 seconds apart.
    final isGrouped = prev != null &&
        prev.sentByMe == m.sentByMe &&
        m.sentAtUtc.difference(prev.sentAtUtc).inSeconds.abs() < 60 &&
        !needsSeparator;

    items.add(_MessageItem(m, isGrouped: isGrouped));
    prev = m;
  }
  return items;
}

// ── Chat-specific local widgets ───────────────────────────────────────────────

/// Avatar with an optional green verified badge — matches the mockup.
class _ChatAvatar extends StatelessWidget {
  final String initials;
  final bool verified;

  const _ChatAvatar({required this.initials, this.verified = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const double size = 36;
    const double badgeSize = 16;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DesignTokens.brand500,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontFamily: DesignTokens.fontDisplay,
                fontWeight: FW.semibold,
                fontSize: DesignTokens.fontSizeSecondary,
                color: Colors.white,
              ),
            ),
          ),
          if (verified)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DesignTokens.green,
                  border: Border.all(
                    color: isDark
                        ? DesignTokens.cardDark
                        : Colors.white,
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.check,
                  size: 9,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rounded pill showing job step/status — sits between the app bar and messages.
class _ChatStatusPill extends StatelessWidget {
  final String status;
  final bool isDark;

  const _ChatStatusPill({required this.status, required this.isDark});

  // Human-readable step label from raw status string.
  static String _label(String status) => switch (status) {
    'Requested' => 'Step 1 of 4 · Requested',
    'Booked'    => 'Step 2 of 4 · Booked',
    'InProgress' || 'In Progress' => 'Step 3 of 4 · In progress',
    'AwaitingConfirmation'        => 'Step 4 of 4 · Awaiting confirmation',
    'Completed'  => 'Step 4 of 4 · Completed',
    'Cancelled'  => 'Cancelled',
    'Disputed'   => 'Disputed',
    _            => status,
  };

  @override
  Widget build(BuildContext context) {
    final bool isAlert = status == 'Disputed';
    final Color bg = isAlert
        ? DesignTokens.inkDanger(isDark).withValues(alpha: Alpha.tintLight)
        : (isDark
            ? DesignTokens.brand100Dark
            : DesignTokens.paperLineLight);
    final Color fg = isAlert
        ? DesignTokens.inkDanger(isDark)
        : (isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s2_5, Space.gutter, Space.s1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.s3,
                vertical: Space.s1_5,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
                border: Border.all(
                  color: isDark
                      ? DesignTokens.paperLineDark
                      : DesignTokens.paperLineLight,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAlert
                        ? Icons.warning_amber_rounded
                        : Icons.access_time_rounded,
                    size: 14,
                    color: fg,
                  ),
                  const SizedBox(width: Space.s1_5),
                  Flexible(
                    child: Text(
                      _label(status),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: DesignTokens.fontBody,
                        fontSize: DesignTokens.fontSizeCaption,
                        fontWeight: FW.medium,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle dotted texture painted behind the message list — matches the mockup's
/// cream background with faint evenly-spaced dots.
class _DottedBackground extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _DottedBackground({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotPatternPainter(isDark: isDark),
      child: child,
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  final bool isDark;
  _DotPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.06))
      ..style = PaintingStyle.fill;

    const double spacing = 20.0;
    const double radius = 1.5;

    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter old) => old.isDark != isDark;
}
