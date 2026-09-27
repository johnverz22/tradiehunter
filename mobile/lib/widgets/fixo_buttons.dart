import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Primary CTA — amber per design-system.html ("hi-vis tape:
/// reserved for the one action that matters most on a screen").
class FixoPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const FixoPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: DesignTokens.amber,
          foregroundColor: DesignTokens.onAmber,
          disabledBackgroundColor: DesignTokens.amber.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: DesignTokens.onAmber),
              )
            : Text(label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Secondary / ghost action — transparent with paper-line border.
class FixoGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const FixoGhostButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(
            color: isDark
                ? DesignTokens.paperLineDark
                : DesignTokens.paperLineLight,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius),
          ),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Brand wordmark: "Fixo" in brand-900 + amber dot. Matches mockup headers.
class FixoWordmark extends StatelessWidget {
  final double fontSize;
  final Color? color;

  const FixoWordmark({super.key, this.fontSize = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = color ??
        (isDark ? DesignTokens.inkDark : DesignTokens.brand900);
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: DesignTokens.fontDisplay,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          letterSpacing: -0.02 * fontSize,
          color: base,
        ),
        children: const [
          TextSpan(text: 'Fixo'),
          TextSpan(
              text: '.', style: TextStyle(color: DesignTokens.amber)),
        ],
      ),
    );
  }
}
