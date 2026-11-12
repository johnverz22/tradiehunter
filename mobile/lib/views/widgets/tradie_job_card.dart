import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../theme/design_tokens.dart';
import '../../utils/money.dart';
import 'compact_progress_bar.dart';
import 'job_status_presentation.dart';

/// The canonical job card for all tradie views (Home dashboard and My Jobs).
///
/// Anatomy:
/// - Title (max 2 lines, ellipsis) with trailing status chip on the same row.
/// - One muted meta line: trade · suburb. The job reference code (preferring
///   [Job.referenceCode], falling back to [Job.id] when ≤12 chars) appears as
///   a small muted mono caption on the trailing edge of the same row — never
///   wraps onto its own line.
/// - Price left, schedule right-aligned ("Wed 4 Nov" / "3:45 PM", relative
///   "Today"/"Tomorrow"). Both in standard ink colour regardless of overdue state.
/// - Segmented progress bar with "Step X of 4" caption.
/// - ONE CTA button when the tradie must act now; otherwise trailing chevron.
/// - Overdue warning: amber card border + "Overdue" chip. Price and schedule
///   text stay in the standard ink colour (warning is on chip/border only).
/// - Whole card is tappable.
class TradieJobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  final bool? isOverdueOverride;

  const TradieJobCard({
    super.key,
    required this.job,
    required this.onTap,
    this.isOverdueOverride,
  });

  bool get isOverdue {
    if (isOverdueOverride != null) return isOverdueOverride!;
    if (job.status != 'Booked') return false;
    final scheduled = job.scheduledStartUtc?.toLocal();
    if (scheduled == null) return false;
    return scheduled.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final th = Theme.of(context).extension<THColors>()!;
    final presentation = JobStatusPresentation.forStatus(job.status);
    final scheduled = job.scheduledStartUtc?.toLocal();
    final overdue = isOverdue;

    // Price string — tabular numerals.
    final priceText =
        job.totalAmount != null ? formatMoney(job.totalAmount!) : null;

    // Schedule: date label over time label with relative "Today"/"Tomorrow".
    String? dateLabel;
    String? timeLabel;
    if (scheduled != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final jobDay = DateTime(scheduled.year, scheduled.month, scheduled.day);

      if (jobDay == today) {
        dateLabel = 'Today';
      } else if (jobDay == tomorrow) {
        dateLabel = 'Tomorrow';
      } else {
        dateLabel = DateFormat('EEE d MMM').format(scheduled);
      }
      timeLabel = DateFormat.jm().format(scheduled);
    }

    // Trade · suburb (never repeat category twice).
    final metaParts = <String>[];
    if (job.category.isNotEmpty) metaParts.add(job.category);
    if (job.suburb.isNotEmpty) metaParts.add(job.suburb);

    // Reference code — prefer server referenceCode over raw id. Only shown
    // when it's a short human-readable code (≤12 chars). Placed on the
    // trailing edge of the meta row, never on its own line.
    final refCode = (job.referenceCode?.isNotEmpty == true)
        ? job.referenceCode!
        : (job.id.length <= 12 ? job.id : '');

    // Overdue status chip vs normal status chip.
    final statusChipWidget = overdue
        ? const StatusChip(
            label: 'Overdue',
            tone: ChipTone.warning,
            icon: Icons.warning_amber_rounded,
          )
        : StatusChip(
            label: presentation.label,
            tone: presentation.chipTone,
            icon: presentation.chipIcon,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          padding: const EdgeInsets.all(Space.s4),
          decoration: BoxDecoration(
            color: DesignTokens.surfaceCard(isDark),
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              color: overdue
                  ? DesignTokens.amber
                  : DesignTokens.paperLine(isDark),
              width: overdue
                  ? Sizes.borderWidthThick
                  : Sizes.borderWidthThin,
            ),
            boxShadow: DesignTokens.cardShadow(isDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: Title (2-line clamp) + status chip ─────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: DesignTokens.fontDisplay,
                        fontSize: DesignTokens.fontSizeH3,
                        fontWeight: FW.bold,
                        height: 1.3,
                        color: th.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.s2),
                  statusChipWidget,
                ],
              ),

              // ── Row 2: trade · suburb  [ref code trailing] ────────────
              // The reference code is a small muted mono caption on the
              // trailing edge of this row. It never takes its own line.
              if (metaParts.isNotEmpty || refCode.isNotEmpty) ...[
                const SizedBox(height: Space.s1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (metaParts.isNotEmpty)
                      Expanded(
                        child: Text(
                          metaParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeSecondary,
                            color: th.textSoft,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (refCode.isNotEmpty) ...[
                      const SizedBox(width: Space.s2),
                      Text(
                        refCode,
                        style: TextStyle(
                          fontFamily: DesignTokens.fontMono,
                          fontSize: DesignTokens.fontSizeMono,
                          fontWeight: FW.medium,
                          color: th.textSoft,
                          letterSpacing: Tracking.wide,
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              // ── Row 3: price | schedule ───────────────────────────────
              if (priceText != null || dateLabel != null) ...[
                const SizedBox(height: Space.s3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (priceText != null)
                      Expanded(
                        child: Text(
                          priceText,
                          style: TextStyle(
                            fontFamily: DesignTokens.fontDisplay,
                            fontSize: DesignTokens.fontSizeAmount,
                            fontWeight: FW.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: th.text,
                          ),
                        ),
                      ),
                    if (priceText != null && dateLabel != null)
                      const SizedBox(width: Space.s2),
                    if (dateLabel != null)
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              dateLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeSecondary,
                                fontWeight: FW.medium,
                                color: th.textSoft,
                              ),
                            ),
                            if (timeLabel != null)
                              Text(
                                timeLabel,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: DesignTokens.fontSizeSecondary,
                                  fontWeight: FW.semibold,
                                  color: th.text,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              // ── Row 4: segmented progress bar ─────────────────────────
              if (presentation.progressStage != null) ...[
                const SizedBox(height: Space.s3),
                CompactProgressBar(
                  completedSteps: presentation.progressStage! + 1,
                  totalSteps: 4,
                  label: presentation.progressLabel,
                ),
              ],

              // ── Row 5: CTA button or chevron ──────────────────────────
              const SizedBox(height: Space.s3),
              if (presentation.tradieActionRequired)
                SizedBox(
                  width: double.infinity,
                  height: Sizes.tapMin,
                  child: Semantics(
                    button: true,
                    label: presentation.tradieAction,
                    child: FilledButton(
                      key: const Key('today_card_cta'),
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignTokens.amber,
                        foregroundColor: DesignTokens.onAmber,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.control),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: DesignTokens.fontBody,
                          fontSize: DesignTokens.fontSizeBody,
                          fontWeight: FW.semibold,
                        ),
                      ),
                      child: Text(presentation.tradieAction),
                    ),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: Sizes.iconMd,
                    color: th.textSoft,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
