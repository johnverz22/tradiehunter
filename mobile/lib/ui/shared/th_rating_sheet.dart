import 'package:flutter/material.dart';

import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import 'th_sheet_chrome.dart';

/// Bottom-sheet rating form (mockup 13-rating-modal), v2 skin.
///
/// Wired to live POST /api/jobs/:id/reviews through [onSubmit], which the
/// caller binds to `ReviewsRepository`.
class ThRatingSheet extends StatefulWidget {
  const ThRatingSheet({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.onSubmit,
  });

  final String jobId;
  final String jobTitle;

  /// Called with (rating, comment) — should call the real API.
  final Future<void> Function(int rating, String? comment) onSubmit;

  static Future<void> show(
    BuildContext context, {
    required String jobId,
    required String jobTitle,
    required Future<void> Function(int, String?) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ThRatingSheet(jobId: jobId, jobTitle: jobTitle, onSubmit: onSubmit),
    );
  }

  @override
  State<ThRatingSheet> createState() => _ThRatingSheetState();
}

class _ThRatingSheetState extends State<ThRatingSheet> {
  static const int _defaultRating = 4;
  static const int _maxChars = 1000;

  int _rating = _defaultRating;
  final _commentCtrl = TextEditingController();
  bool _sending = false;
  bool _submitted = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await widget.onSubmit(
        _rating,
        _commentCtrl.text.isEmpty ? null : _commentCtrl.text,
      );
      if (mounted) setState(() => _submitted = true);
      await Future<void>.delayed(THDurations.sheetDelay);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        THNotice.error(context, 'Failed to submit review. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ThScope(
      child: Builder(
        builder: (context) {
          final c = context.th;
          return ThSheetFrame(
            child: _submitted
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: Space.s2,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: c.success,
                        size: Sizes.avatarLg,
                      ),
                      const THText(
                        'Review submitted!',
                        style: THTextStyle.h2,
                        align: TextAlign.center,
                      ),
                      const THText(
                        'Thank you for your feedback.',
                        tone: THTone.soft,
                        align: TextAlign.center,
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: Space.s3,
                    children: [
                      const THText(
                        'Job Complete!',
                        style: THTextStyle.h2,
                        align: TextAlign.center,
                      ),
                      THText(
                        widget.jobTitle,
                        tone: THTone.soft,
                        align: TextAlign.center,
                      ),
                      const THText(
                        'How was the service?',
                        style: THTextStyle.label,
                        align: TextAlign.center,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) {
                            return IconButton(
                              tooltip: 'Rate ${i + 1} star${i == 0 ? '' : 's'}',
                              onPressed: () => setState(() => _rating = i + 1),
                              icon: Icon(
                                Icons.star_rounded,
                                size: Sizes.fab,
                                color: i < _rating ? c.accent : c.track,
                              ),
                            );
                          }),
                        ),
                      ),
                      THTextField(
                        controller: _commentCtrl,
                        hint: 'Write a review… (optional)',
                        maxLength: _maxChars,
                        minLines: 3,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      THButton(
                        label: 'Submit Review',
                        kind: THButtonKind.accent,
                        loading: _sending,
                        onPressed: _sending ? null : _submit,
                      ),
                      THButton(
                        label: 'Skip for now',
                        kind: THButtonKind.ghost,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
