import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/fixo_cards.dart';
import 'compact_progress_bar.dart';
import 'job_progress_dots.dart';

/// Modern job card with 5-part layout per v1.6 specification:
/// 1. Header row: tradie avatar (if matched) + name + status pill (top-right)
/// 2. Job title + secondary line (subdued category · suburb · reference)
/// 3. Price at 24/700 + date
/// 4. Single 48px primary button matching state
/// 5. Compact progress bar
class ModernJobCard extends StatelessWidget {
  final String title;
  final String category;
  final String suburb;

  /// Optional ZIP / postal code — rendered in the secondary line.
  final String? zipCode;

  /// Short mono reference line, e.g. job id or relative time.
  final String? reference;
  final String? priceLabel;
  final String? scheduleLabel;

  final String? status;
  final FixoBadgeKind statusKind;
  final bool isUrgent;
  final String? progressStatus;
  final VoidCallback? onTap;
  final String? identityLabel;
  final String? actionLabel;

  /// When true the action button uses a tonal style (brand tint bg, brand text)
  /// instead of the amber primary style. Used for non-urgent actions like
  /// "Open chat" on Booked/InProgress cards.
  final bool actionIsTonal;

  /// When true the action button uses secondary / outline style (e.g. "Pay now"
  /// on AwaitingPayment cards per mockup).
  final bool actionIsSecondary;

  final bool isAttention;

  const ModernJobCard({
    super.key,
    required this.title,
    required this.category,
    required this.suburb,
    this.zipCode,
    this.reference,
    this.priceLabel,
    this.scheduleLabel,
    this.status,
    this.statusKind = FixoBadgeKind.waiting,
    this.isUrgent = false,
    this.progressStatus,
    this.onTap,
    this.identityLabel,
    this.actionLabel,
    this.actionIsTonal = false,
    this.actionIsSecondary = false,
    this.isAttention = false,
  });

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasIdentity =
        identityLabel != null && identityLabel!.trim().isNotEmpty;
    final hasHeader = hasIdentity || isUrgent || status != null;
    final mutedColor = DesignTokens.inkSoft(isDark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: DesignTokens.surfaceCard(isDark),
            borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
            boxShadow: DesignTokens.cardShadow(isDark),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DesignTokens.space5),
            decoration: isAttention
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.4, 1],
                      colors: [
                        DesignTokens.brand500.withValues(alpha: 0.18),
                        DesignTokens.brand500.withValues(alpha: 0.06),
                        DesignTokens.brand500.withValues(alpha: 0),
                      ],
                    ),
                  )
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                    border: Border.all(color: DesignTokens.paperLine(isDark)),
                  ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isAttention) ...[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: TypeTokens.fontDisplay,
                    fontSize: DesignTokens.fontSizeH3,
                    fontWeight: FW.bold,
                  ),
                ),
                const SizedBox(height: Space.s3),
              ],
              // ── 1. Header row: tradie avatar + name + status pill (top-right)
              if (hasHeader)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (hasIdentity) ...[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isAttention
                              ? LinearGradient(
                                  colors: [
                                    DesignTokens.brand900,
                                    DesignTokens.brand500,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isAttention ? null : DesignTokens.brand500,
                        ),
                        padding: isAttention
                            ? const EdgeInsets.all(Space.s0_5)
                            : EdgeInsets.zero,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isAttention
                                ? (isDark
                                    ? DesignTokens.surfaceCard(isDark)
                                    : Colors.white)
                                : DesignTokens.brand500,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initials(identityLabel!),
                            style: TextStyle(
                              fontFamily: DesignTokens.fontDisplay,
                              fontSize: DesignTokens.fontSizeCaption,
                              fontWeight: FW.bold,
                              color: isAttention
                                  ? (isDark
                                      ? Colors.white
                                      : DesignTokens.brand900)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.s2),
                      Expanded(
                        child: Text(
                          identityLabel!,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FW.semibold,
                            color: DesignTokens.foreground(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (isUrgent)
                      const Flexible(
                        child: StatusBadge(
                          label: 'URGENT',
                          kind: FixoBadgeKind.actionNeeded,
                        ),
                      )
                    else if (status != null)
                      Flexible(
                        child: StatusBadge(label: status!, kind: statusKind),
                      ),
                  ],
                ),

              // ── 2. Job title + secondary line (smaller, subdued) ───────────
              if (hasHeader) const SizedBox(height: Space.s2_5),
              if (!isAttention)
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FW.bold,
                    fontSize: DesignTokens.fontSizeH3,
                    height: 1.3,
                    color: DesignTokens.foreground(isDark),
                  ),
                ),
              // Secondary line: category · suburb · reference
              // Hidden on attention cards (H07 layout has no secondary line).
              if (!isAttention)
                Builder(
                builder: (context) {
                  final secondaryItems = <Widget>[];
                  void addItem(String text, {bool mono = false}) {
                    if (text.trim().isEmpty) return;
                    if (secondaryItems.isNotEmpty) {
                      secondaryItems.add(
                        Text(
                          ' · ',
                          style: TextStyle(fontSize: DesignTokens.fontSizeSecondary, color: mutedColor),
                        ),
                      );
                    }
                    secondaryItems.add(
                      Text(
                        text.trim(),
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeSecondary,
                          fontFamily: mono
                              ? DesignTokens.fontMono
                              : DesignTokens.fontBody,
                          color: mutedColor,
                        ),
                      ),
                    );
                  }

                  addItem(category);
                  addItem(suburb);
                  if (zipCode != null) addItem(zipCode!);
                  if (reference != null) addItem(reference!, mono: true);

                  if (secondaryItems.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: Space.s1),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: secondaryItems,
                    ),
                  );
                },
              ),

              // ── 3. Price + date row ────────────────────────────────────────
              if (priceLabel != null || scheduleLabel != null) ...[
                if (isAttention) ...[
                  const SizedBox(height: Space.s3_5),
                  Divider(height: 1, color: DesignTokens.paperLine(isDark)),
                ],
                const SizedBox(height: Space.s3),
                if (isAttention)
                  // Design: price left baseline, time right baseline on same row
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (priceLabel != null)
                        Text(
                          priceLabel!,
                          style: TextStyle(
                            fontFamily: DesignTokens.fontBody,
                            fontSize: DesignTokens.fontSizeAmountSm,
                            fontWeight: FW.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: DesignTokens.foreground(isDark),
                          ),
                        ),
                      if (scheduleLabel != null)
                        Text(
                          scheduleLabel!,
                          style: TextStyle(
                            fontFamily: DesignTokens.fontBody,
                            fontSize: DesignTokens.fontSizeSecondary,
                            fontWeight: FW.medium,
                            color: mutedColor,
                          ),
                        ),
                    ],
                  )
                else
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      if (priceLabel != null)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            priceLabel!,
                            style: TextStyle(
                              fontFamily: DesignTokens.fontDisplay,
                              fontSize: DesignTokens.fontSizeAmount,
                              fontWeight: FW.bold,
                              color: DesignTokens.foreground(isDark),
                            ),
                          ),
                        ),
                      if (scheduleLabel != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 14,
                              color: mutedColor,
                            ),
                            const SizedBox(width: Space.s1),
                            Flexible(
                              child: Text(
                                scheduleLabel!,
                                style: TextStyle(
                                  fontSize: DesignTokens.fontSizeSecondary,
                                  fontWeight: FW.medium,
                                  color: mutedColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
              ],

              if (isAttention && progressStatus != null) ...[
                const SizedBox(height: Space.s3),
                JobProgressDots(status: progressStatus!),
              ],
              // ── 4. Single 48px primary button matching state ───────────────
              if (actionLabel != null && onTap != null) ...[
                const SizedBox(height: Space.s3_5),
                SizedBox(
                  width: double.infinity,
                  height: DesignTokens.targetMinimum,
                  child: Builder(builder: (context) {
                    if (actionIsTonal) {
                      // Tonal: brand-tint background, brand text — for
                      // non-urgent actions like "Open chat" on booked cards.
                      final colors =
                          Theme.of(context).extension<THColors>()!;
                      return TextButton(
                        key: const Key('job_card_primary_action'),
                        onPressed: onTap,
                        style: TextButton.styleFrom(
                          backgroundColor: colors.tintBrand,
                          foregroundColor: colors.textBrand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DesignTokens.radiusControl,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.s4,
                          ),
                          textStyle: const TextStyle(
                            fontFamily: DesignTokens.fontBody,
                            fontSize: DesignTokens.fontSizeBody,
                            fontWeight: FW.semibold,
                          ),
                        ),
                        child: Text(actionLabel!),
                      );
                    }
                    if (actionIsSecondary) {
                      // Secondary / ghost: outline button with brand text
                      // (e.g. "Pay now" in mockup).
                      return TextButton(
                        key: const Key('job_card_primary_action'),
                        onPressed: onTap,
                        style: TextButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.transparent
                              : DesignTokens.surfaceCard(isDark),
                          foregroundColor: DesignTokens.foregroundBrand(isDark),
                          side: BorderSide(
                            color: DesignTokens.borderControl(isDark),
                            width: DesignTokens.borderWidthFor(isDark),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DesignTokens.radiusControl,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.s4,
                          ),
                          textStyle: const TextStyle(
                            fontFamily: DesignTokens.fontDisplay,
                            fontSize: DesignTokens.fontSizeBody,
                            fontWeight: FW.semibold,
                          ),
                        ),
                        child: Text(actionLabel!),
                      );
                    }
                    // Primary (amber): attention cards and payment CTAs.
                    return TextButton(
                      key: const Key('job_card_primary_action'),
                      onPressed: onTap,
                      style: TextButton.styleFrom(
                        backgroundColor: DesignTokens.amber,
                        foregroundColor: DesignTokens.onAmber,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusControl,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.s4,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: DesignTokens.fontDisplay,
                          fontSize: DesignTokens.fontSizeBody,
                          fontWeight: FW.semibold,
                        ),
                      ),
                      child: Text(actionLabel!),
                    );
                  }),
                ),
              ],

              // ── 5. Compact progress bar ────────────────────────────────────
              if (!isAttention && progressStatus != null) ...[
                const SizedBox(height: DesignTokens.space4),
                CompactProgressBar(status: progressStatus!),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
}
