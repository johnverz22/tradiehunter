import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/design_tokens.dart';

/// Bottom-sheet rating form from mockup 13-rating-modal.
/// Triggered on SignalR `job-status=Complete` or via demo entry point.
///
/// M4-05: Wired to live POST /api/jobs/:id/reviews via [ReviewsRepository].
/// Character counter added to comment field.
class RatingSheet extends ConsumerStatefulWidget {
  final String jobId;
  final String jobTitle;

  /// Called with (rating, comment) — should call the real API.
  final Future<void> Function(int rating, String? comment) onSubmit;

  const RatingSheet({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required String jobId,
    required String jobTitle,
    required Future<void> Function(int, String?) onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          RatingSheet(jobId: jobId, jobTitle: jobTitle, onSubmit: onSubmit),
    );
  }

  @override
  ConsumerState<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<RatingSheet> {
  int _rating = 4;
  final _commentCtrl = TextEditingController();
  bool _sending = false;
  bool _submitted = false;

  static const int _maxChars = 1000;

  @override
  void initState() {
    super.initState();
    _commentCtrl.addListener(() => setState(() {}));
  }

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
      await Future<void>.delayed(FixoDurations.sheetDelay);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit review. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final charCount = _commentCtrl.text.length;
    final atLimit = charCount >= _maxChars;

    return Container(
      padding: EdgeInsets.fromLTRB(Space.s7, Space.s4, Space.s7, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceCard(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.tile)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? DesignTokens.paperLineDark
                  : DesignTokens.paperLineLight,
              borderRadius: BorderRadius.circular(Radii.micro),
            ),
          ),
          const SizedBox(height: Space.s5),

          // Success state
          if (_submitted) ...[
            const Icon(Icons.check_circle, color: DesignTokens.green, size: 48),
            const SizedBox(height: Space.s3),
            Text(
              'Review submitted!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FW.bold,
              ),
            ),
            const SizedBox(height: Space.s2),
            Text(
              'Thank you for your feedback.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            Text(
              'Job Complete!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FW.bold,
              ),
            ),
            const SizedBox(height: Space.s1_5),
            Text(
              widget.jobTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.s5),
            const Text(
              'How was the service?',
              style: TextStyle(fontSize: DesignTokens.fontSizeBody, fontWeight: FW.semibold),
            ),
            const SizedBox(height: Space.s2),

            // Star rating row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return IconButton(
                  onPressed: () => setState(() => _rating = i + 1),
                  icon: Icon(
                    Icons.star,
                    size: 32,
                    color: filled
                        ? DesignTokens.amber
                        : (isDark
                              ? DesignTokens.paperLineDark
                              : DesignTokens.brand100Light),
                  ),
                );
              }),
            ),
            const SizedBox(height: Space.s3),

            // Comment field with character counter
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              maxLength: _maxChars,
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$currentLength / $maxLength',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: atLimit
                              ? DesignTokens.inkDanger(
                                  theme.brightness == Brightness.dark,
                                )
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
              decoration: const InputDecoration(
                hintText: 'Write a review… (optional)',
              ),
            ),
            const SizedBox(height: Space.s4),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.amber,
                  foregroundColor: DesignTokens.onAmber,
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Submit Review',
                        style: TextStyle(
                          fontWeight: FW.semibold,
                          fontSize: DesignTokens.fontSizeBody,
                        ),
                      ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Skip for now'),
            ),
          ],
        ],
      ),
    );
  }
}
