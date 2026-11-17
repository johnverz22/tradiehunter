import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';

class HoReviewScreen extends ConsumerStatefulWidget {
  const HoReviewScreen({
    super.key,
    required this.job,
    required this.tradie,
    required this.hasReview,
  });

  final Job job;
  final UserProfile? tradie;
  final bool hasReview;

  @override
  ConsumerState<HoReviewScreen> createState() => _HoReviewScreenState();
}

class _HoReviewScreenState extends ConsumerState<HoReviewScreen> {
  bool _hasReview = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _hasReview = widget.hasReview;
  }

  Future<void> _showReviewSheet() async {
    final result = await showModalBottomSheet<({int rating, String comment})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ThScope(
        themeMode: ref.read(themeModeProvider),
        child: _ReviewSheet(
          tradieName: _tradieName,
          jobTitle: widget.job.title,
        ),
      ),
    );
    if (result == null || !mounted || _busy) return;
    final tradieId = widget.job.matchedTradieId;
    if (tradieId == null || tradieId.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(reviewsRepositoryProvider)
          .submitReview(
            widget.job.id,
            result.rating,
            result.comment,
            revieweeId: tradieId,
          );
      if (!mounted) return;
      setState(() => _hasReview = true);
      THNotice.success(context, 'Your review has been submitted.');
    } on ProfileApiException catch (error) {
      if (mounted) THNotice.errorDynamic(context, error.message);
    } catch (_) {
      if (mounted) {
        THNotice.error(
          context,
          'Could not submit your review. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _tradieName =>
      widget.tradie?.businessName?.trim().isNotEmpty == true
      ? widget.tradie!.businessName!.trim()
      : widget.tradie?.fullName ??
            widget.job.matchedTradieName ??
            'your tradie';

  @override
  Widget build(BuildContext context) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: THScaffold(
      appBar: THAppBar(title: 'How did it go?', subtitle: _tradieName),
      stickyBar: _hasReview || widget.job.matchedTradieId == null
          ? null
          : THStickyBar(
              children: [
                THButton(
                  key: const Key('leave_review_button'),
                  label: _busy ? 'Submitting…' : 'Leave a review',
                  loading: _busy,
                  kind: THButtonKind.accent,
                  onPressed: _busy ? null : _showReviewSheet,
                ),
              ],
            ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          THCard(
            children: [
              Center(
                child: Column(
                  spacing: Space.s3,
                  children: [
                    if (widget.tradie != null)
                      THAvatar(widget.tradie!.initials, size: THAvatarSize.lg),
                    const THText(
                      'Job completed',
                      style: THTextStyle.h2,
                      align: TextAlign.center,
                    ),
                    THText(
                      _tradieName,
                      style: THTextStyle.body,
                      align: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          THCard(
            children: [
              THText(widget.job.title, style: THTextStyle.title),
              const SizedBox(height: Space.s1),
              const THText(
                'Your feedback helps other homeowners choose with confidence.',
                style: THTextStyle.body,
                tone: THTone.soft,
              ),
            ],
          ),
          if (_hasReview)
            const THCard(
              tone: THCardTone.accent,
              children: [
                THText('Review submitted', style: THTextStyle.title),
                SizedBox(height: Space.s1),
                THText(
                  'Your review is private until both parties review or the review period ends.',
                  style: THTextStyle.body,
                  tone: THTone.soft,
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.tradieName, required this.jobTitle});
  final String tradieName;
  final String jobTitle;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _comment = TextEditingController();
  int _rating = 4;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        Sizes.gutter,
        Space.s5,
        Sizes.gutter,
        Space.s5 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          THText('Review ${widget.tradieName}', style: THTextStyle.title),
          THText(widget.jobTitle, style: THTextStyle.meta, tone: THTone.soft),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var value = 1; value <= 5; value++)
                IconButton(
                  key: Key('star_$value'),
                  tooltip: '$value stars',
                  onPressed: () => setState(() => _rating = value),
                  icon: Icon(
                    value <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: Sizes.avatarSm,
                    color: value <= _rating
                        ? context.th.accent
                        : context.th.textSoft,
                  ),
                ).testId('star_$value'),
            ],
          ),
          THTextField(
            label: 'Comment (optional)',
            hint: 'Share what went well',
            controller: _comment,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
          ),
          THButton(
            key: const Key('submit_review_button'),
            label: 'Submit review',
            kind: THButtonKind.accent,
            onPressed: () => Navigator.pop(context, (
              rating: _rating,
              comment: _comment.text.trim(),
            )),
          ),
        ],
      ),
    ),
  );
}
