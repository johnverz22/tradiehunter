import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Compact 4-segment progress bar — v1.6 cpb spec.
///
/// Track: 6px tall, 4 equal segments separated by 3px gaps.
/// Segment colours:
///   filled (normal)   → white on dark bands, brand700 on light cards
///   empty  (normal)   → rgba(255,255,255,.25) on dark / track on light
///   muted variant     → every segment rgba(255,255,255,.55); caption dimmer
/// Caption below: 'Step X of 4 · Status text', status part in soft color.
///
/// Accepts the new typed signature while staying backward-compatible
/// with call sites that still pass [status] alone.
class CompactProgressBar extends StatelessWidget {
  // ── v1.6 typed signature ────────────────────────────────────────────────
  final int? totalSteps;
  final int? completedSteps;
  final String? label;
  final String? sublabel;
  final bool muted;

  // ── Legacy compat ────────────────────────────────────────────────────────
  final String? status;
  final int? currentStep; // 1-based (1..4)
  final String? stepLabel;
  final bool? isTerminal;
  final bool inline;

  /// Force white-alpha segment colours — set when the bar sits on a dark band.
  final bool onDark;

  /// Optional widget rendered at the end of the caption line (e.g. chevron).
  final Widget? trailing;

  /// Optional tap handler for the entire caption line (text + trailing).
  final VoidCallback? onCaptionTap;

  const CompactProgressBar({
    super.key,
    // v1.6 API
    this.totalSteps,
    this.completedSteps,
    this.label,
    this.sublabel,
    this.muted = false,
    this.onDark = false,
    this.trailing,
    this.onCaptionTap,
    // legacy API
    this.status,
    this.currentStep,
    this.stepLabel,
    this.isTerminal,
    this.inline = false,
  });

  // ── Derived values ────────────────────────────────────────────────────────

  bool get _isTerminal {
    if (isTerminal != null) return isTerminal!;
    return switch (status) {
      'Cancelled' || 'Expired' || 'Disputed' => true,
      _ => false,
    };
  }

  /// 0-based index of the last *filled* segment.
  int get _stepIndex {
    // v1.6 API takes priority.
    if (completedSteps != null) {
      return (completedSteps! - 1).clamp(0, (totalSteps ?? 4) - 1);
    }
    if (currentStep != null) return (currentStep! - 1).clamp(0, 3);
    return switch (status) {
      'Requested' || 'AwaitingPayment' || 'PaymentReview' => 0,
      'Booked' => 1,
      'InProgress' || 'AwaitingConfirmation' => 2,
      'Completed' => 3,
      'Cancelled' => 1,
      'Expired' => 0,
      'Disputed' => 2,
      _ => 0,
    };
  }

  int get _total => totalSteps ?? 4;

  bool get _isMuted {
    if (muted) return true;
    return _isTerminal;
  }

  String get _captionMain {
    if (label != null) return label!;
    if (stepLabel != null) return stepLabel!;
    if (_isTerminal) {
      return switch (status) {
        'Cancelled' => 'Cancelled',
        'Expired' => 'Expired',
        'Disputed' => 'Disputed',
        _ => status ?? 'Step ${_stepIndex + 1} of $_total',
      };
    }
    return 'Step ${_stepIndex + 1} of $_total';
  }

  /// Sub-caption is suppressed for the common case — the status chip in the
  /// card already communicates "In progress" / "Booked" etc., so repeating it
  /// in the progress bar caption makes hierarchy flat and wastes height.
  ///
  /// Pass an explicit [sublabel] to restore a sub-caption when needed (e.g.
  /// detail pages that omit the chip).
  String? get _captionSub {
    if (sublabel != null) return sublabel;
    // Never auto-generate the segment label — rely on the StatusChip for that.
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (inline) return _buildInline(context, isDark);
    return _buildBlock(context, isDark);
  }

  /// Full-width block variant (default).
  Widget _buildBlock(BuildContext context, bool isDark) {
    // On dark bands (hero, status strip, attcard gradient) segments use white-alpha.
    // onDark=true forces white colours even in a light-theme screen.
    final bool treatAsDark = onDark || isDark;
    final Color filledColor;
    final Color emptyColor;

    if (_isMuted) {
      filledColor = Colors.white.withValues(alpha: Alpha.fillDark);
      emptyColor = Colors.white.withValues(alpha: Alpha.fillDark);
    } else if (treatAsDark) {
      filledColor = Colors.white;
      emptyColor = Colors.white.withValues(alpha: Alpha.border);
    } else {
      filledColor = DesignTokens.brand700;
      emptyColor = DesignTokens.brand900.withValues(alpha: Alpha.tintStandard);
    }

    final captionMainStyle = TextStyle(
      fontFamily: DesignTokens.fontBody,
      fontSize: onDark ? DesignTokens.fontSizeStep : DesignTokens.fontSizeCaption,
      fontWeight: FW.semibold,
      color: _isMuted
          ? (treatAsDark
              ? Colors.white.withValues(alpha: Alpha.outlineDark)
              : DesignTokens.inkSoftLight.withValues(alpha: Alpha.fillDark))
          : (treatAsDark ? Colors.white.withValues(alpha: Alpha.iconOnGradientStrong) : DesignTokens.brand900),
      height: 1.2,
    );
    final captionSubStyle = captionMainStyle.copyWith(
      fontWeight: FW.regular,
      color: _isMuted
          ? (treatAsDark
              ? Colors.white.withValues(alpha: Alpha.borderStrong)
              : DesignTokens.inkSoftLight.withValues(alpha: Alpha.shadow))
          : (treatAsDark ? Colors.white.withValues(alpha: Alpha.iconOnGradientSoft) : DesignTokens.inkSoft(isDark)),
    );

    return Semantics(
      label:
          'Progress: $_captionMain${_captionSub != null ? ' · $_captionSub' : ''}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Track: 4 segments × 6px, 3px gaps.
            Row(
              children: List.generate(_total, (index) {
                final filled = _isMuted ? false : (index <= _stepIndex);
                // For terminal: fill up to _stepIndex but not if it equals Done.
                final shouldFill = _isMuted
                    ? false
                    : (_isTerminal ? (index <= _stepIndex && index < 3) : filled);

                return Expanded(
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.only(
                      left: index == 0 ? 0 : 1.5,
                      right: index == _total - 1 ? 0 : 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: shouldFill ? filledColor : emptyColor,
                      borderRadius: BorderRadius.circular(Radii.micro),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: Space.s1_5),
            // Caption: "Step X of 4 · Status" + optional trailing widget
            GestureDetector(
              onTap: onCaptionTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _captionMain,
                            style: captionMainStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_captionSub != null) ...[
                          Text(
                            ' · ',
                            style: captionSubStyle,
                          ),
                          Flexible(
                            child: Text(
                              _captionSub!,
                              style: captionSubStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Inline pill variant (used for compact list rows).
  Widget _buildInline(BuildContext context, bool isDark) {
    final fillColor = _isMuted
        ? DesignTokens.inkSoft(isDark)
        : (isDark ? DesignTokens.brand300 : DesignTokens.brand700);

    final caption = _captionSub != null
        ? '$_captionMain · $_captionSub'
        : _captionMain;

    return Semantics(
      label: 'Progress: $caption',
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: Space.s2_5),
        decoration: BoxDecoration(
          color: fillColor.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
          border: Border.all(color: fillColor.withValues(alpha: Alpha.borderMid)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: fillColor),
            ),
            const SizedBox(width: Space.s1_5),
            Flexible(
              child: Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: DesignTokens.fontBody,
                  fontSize: DesignTokens.fontSizeCaption,
                  fontWeight: FW.semibold,
                  color: isDark
                      ? Colors.white.withValues(alpha: Alpha.navBarStrong)
                      : fillColor,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
