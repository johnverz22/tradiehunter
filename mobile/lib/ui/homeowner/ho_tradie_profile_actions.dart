import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../network/api_error.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../widgets/rating_sheet.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import 'ho_tradie_profile_mapper.dart';

class ThTradieProfileActions extends StatelessWidget {
  const ThTradieProfileActions({
    super.key,
    required this.profileId,
    required this.isTradie,
    required this.viewerRole,
    this.jobId,
    this.jobEntry,
  });

  final String profileId;
  final bool isTradie;
  final int? viewerRole;
  final String? jobId;
  final TradieListEntry? jobEntry;

  @override
  Widget build(BuildContext context) {
    final inJobContext = jobId != null && jobId!.isNotEmpty;
    if (inJobContext) {
      return _JobRequestBar(
        key: const Key('job_request_actions'),
        profileId: profileId,
        jobId: jobId!,
        jobEntry: jobEntry,
      );
    }
    return _ContextualActions(
      profileId: profileId,
      isTradie: isTradie,
      viewerRole: viewerRole,
    );
  }
}

class _JobRequestBar extends ConsumerStatefulWidget {
  const _JobRequestBar({
    super.key,
    required this.profileId,
    required this.jobId,
    this.jobEntry,
  });

  final String profileId;
  final String jobId;
  final TradieListEntry? jobEntry;

  @override
  ConsumerState<_JobRequestBar> createState() => _JobRequestBarState();
}

class _JobRequestBarState extends ConsumerState<_JobRequestBar> {
  bool _sending = false;

  Future<void> _request() async {
    if (_sending) return;
    final controller = TextEditingController();
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          Sizes.gutter,
          Space.s6,
          Sizes.gutter,
          MediaQuery.viewInsetsOf(ctx).bottom + Space.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const THText('Request this tradie', style: THTextStyle.h2),
            const SizedBox(height: Space.s2),
            const THText(
              "Add an optional message — it's the only way to reach them "
              'before they accept.',
              style: THTextStyle.meta,
              tone: THTone.soft,
            ),
            const SizedBox(height: Space.s4),
            THTextField(
              label: 'Message (optional)',
              hint:
                  'e.g. Hi, the job is the flat above — call before you come.',
              controller: controller,
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: Space.s4),
            THButton(
              key: const Key('send_request_button'),
              label: 'Send request',
              kind: THButtonKind.accent,
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            ),
          ],
        ),
      ),
    );
    if (message == null || !mounted) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(jobsRepositoryProvider)
          .requestTradieForJob(
            widget.jobId,
            widget.profileId,
            message: message,
          );
      if (!mounted) return;
      final gstLabel = gstLabelFor(widget.jobEntry?.isGstRegistered);
      context.push('/jobs/${widget.jobId}/request', extra: gstLabel);
    } on ProfileApiException catch (e) {
      if (!mounted) return;
      THNotice.errorDynamic(context, e.message);
    } catch (_) {
      if (!mounted) return;
      THNotice.error(context, NoticeCopy.requestFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return THStickyBar(
      children: [
        THButton(
          key: const Key('request_this_tradie_button'),
          label: 'Request this tradie',
          kind: THButtonKind.accent,
          loading: _sending,
          onPressed: _sending
              ? null
              : () {
                  unawaited(_request());
                },
        ),
      ],
    );
  }
}

class _ContextualActions extends ConsumerStatefulWidget {
  const _ContextualActions({
    required this.profileId,
    required this.isTradie,
    required this.viewerRole,
  });

  final String profileId;
  final bool isTradie;
  final int? viewerRole;

  @override
  ConsumerState<_ContextualActions> createState() => _ContextualActionsState();
}

class _ContextualActionsState extends ConsumerState<_ContextualActions> {
  static const _chatClosed = {'Completed', 'Cancelled', 'Disputed'};

  ConversationSummary? _shared;
  List<Job>? _requestable;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final conversations = await ref
          .read(chatRepositoryProvider)
          .getConversations();
      final open = conversations
          .where(
            (c) =>
                c.otherUserId == widget.profileId &&
                !_chatClosed.contains(c.status),
          )
          .toList();
      if (mounted) {
        setState(() => _shared = open.isEmpty ? null : open.first);
      }
    } catch (_) {
      // No conversations load → Message stays hidden.
    }

    if (widget.isTradie && widget.viewerRole == 0) {
      try {
        final jobs = await ref
            .read(jobsRepositoryProvider)
            .getMyJobs(status: 'Requested');
        final open = thRequestableJobs(jobs);
        if (mounted) setState(() => _requestable = open);
      } catch (_) {
        if (mounted) setState(() => _requestable = const []);
      }
    }
  }

  Future<void> _message() async {
    final jobId = _shared?.jobId;
    if (jobId == null) return;
    await context.push('/chat/$jobId');
  }

  Future<void> _request() async {
    final eligible = _requestable;
    if (eligible == null || eligible.isEmpty || _sending) return;
    Job? job = eligible.length == 1 ? eligible.first : null;
    job ??= await showModalBottomSheet<Job>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                Sizes.gutter,
                Space.s4,
                Sizes.gutter,
                Space.s2,
              ),
              child: THText('Request this tradie', style: THTextStyle.h2),
            ),
            for (final job in eligible)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Sizes.gutter,
                  0,
                  Sizes.gutter,
                  Space.s2,
                ),
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, job),
                  child: THListRow(
                    icon: Icons.work_outline_rounded,
                    title: job.title,
                    subtitle: job.suburb.isNotEmpty ? job.suburb : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (job == null || !mounted) return;

    setState(() => _sending = true);
    try {
      final ok = await ref
          .read(jobsRepositoryProvider)
          .requestTradie(job.id, widget.profileId);
      if (!mounted) return;
      if (ok) {
        THNotice.success(
          context,
          'Request sent — you’ll be notified when they respond.',
        );
      } else {
        THNotice.warning(context, 'This job is no longer open for requests.');
      }
    } catch (_) {
      if (!mounted) return;
      THNotice.error(context, NoticeCopy.requestFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canMessage = _shared != null;
    final canRequest = _requestable != null && _requestable!.isNotEmpty;
    if (!canMessage && !canRequest) return const SizedBox.shrink();

    final message = THButton(
      label: 'Message',
      kind: THButtonKind.secondary,
      icon: Icons.chat_bubble_outline_rounded,
      onPressed: canMessage
          ? () {
              unawaited(_message());
            }
          : null,
    );

    if (!canRequest) return THStickyBar(children: [message]);

    return THStickyBar(
      children: [
        Expanded(flex: 1, child: message),
        Expanded(
          flex: 2,
          child: THButton(
            key: const Key('request_tradie_button'),
            label: 'Request for a job',
            kind: THButtonKind.accent,
            loading: _sending,
            onPressed: _sending
                ? null
                : () {
                    unawaited(_request());
                  },
          ),
        ),
      ],
    );
  }
}

Future<void> thLeaveReview(
  BuildContext context,
  WidgetRef ref,
  String profileId,
  String viewerId,
) async {
  List<Job> jobs;
  try {
    jobs = await ref.read(jobsRepositoryProvider).getMyJobs();
  } catch (_) {
    if (context.mounted) {
      THNotice.error(context, 'Could not check completed jobs. Try again.');
    }
    return;
  }
  final job = thCompletedSharedJob(
    jobs,
    viewerId: viewerId,
    profileId: profileId,
  );
  if (!context.mounted) return;
  if (job == null) {
    THNotice.info(context, NoticeCopy.reviewsLocked);
    return;
  }
  await RatingSheet.show(
    context,
    jobId: job.id,
    jobTitle: job.title,
    onSubmit: (rating, comment) => ref
        .read(reviewsRepositoryProvider)
        .submitReview(job.id, rating, comment, revieweeId: profileId),
  );
}

Future<void> thReportUser(
  BuildContext context,
  WidgetRef ref,
  String profileId,
) async {
  final reasonController = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Report abuse'),
      content: TextField(
        controller: reasonController,
        decoration: const InputDecoration(
          hintText: 'What happened? (optional)',
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
          child: const Text('Report'),
        ),
      ],
    ),
  );
  if (reason == null) return;
  try {
    await ref
        .read(profileRepositoryProvider)
        .reportUser(profileId, reason: reason);
    if (!context.mounted) return;
    THNotice.success(context, NoticeCopy.reportSent);
  } catch (e) {
    if (!context.mounted) return;
    final message = e is DioException
        ? friendlyDioError(e, tag: 'PublicProfile.report')
        : e.toString();
    THNotice.errorDynamic(context, message);
  }
}

Future<void> thBlockUser(
  BuildContext context,
  WidgetRef ref,
  String profileId,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Block user?'),
      content: const Text('You will no longer be matched with this user.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (confirm != true) return;
  try {
    await ref.read(profileRepositoryProvider).blockUser(profileId);
    if (!context.mounted) return;
    THNotice.info(context, NoticeCopy.userBlocked);
  } catch (e) {
    if (!context.mounted) return;
    final message = e is DioException
        ? friendlyDioError(e, tag: 'PublicProfile.block')
        : e.toString();
    THNotice.errorDynamic(context, message);
  }
}
