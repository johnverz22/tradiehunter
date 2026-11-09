import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';

/// Consistent screen header replacing plain [AppBar] across the app.
/// This is the model for every screen header (see My Jobs):
///
/// - 64px bar, background always equals the scaffold background so the bar
///   never bands against the body in either theme.
/// - 0.5 hairline in the paper-line token.
/// - [title] in the Display font (Space Grotesk, w700, 22sp, brand-900).
/// - Back uses [FixoBackButton] (iOS chevron, 18px) whenever [showBack] is
///   true and the route can pop. Root tabs pass `showBack: false`.
/// - [subtitle] + [leading] support the chat header (avatar + status line)
///   without forking a second header style.
/// - [actions] accepts icon buttons for the right side (edit, search, etc.).
///
/// Usage:
/// ```dart
/// Scaffold(
///   appBar: FixoAppBar(title: 'My Jobs', showBack: false),
///   ...
/// )
/// ```
class FixoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showBack;
  final List<Widget> actions;

  const FixoAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.showBack = true,
    this.actions = const [],
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 72 : 80);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canPop = showBack && Navigator.of(context).canPop();

    // Restore the theme-appropriate status bar icon colour whenever this
    // app bar is visible. Screens that don't use a real Flutter AppBar won't
    // pick up AppBarTheme.systemOverlayStyle, so we do it explicitly here.
    // Dashboards override this with their own AnnotatedRegion.light.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Container(
        height: preferredSize.height + MediaQuery.of(context).padding.top,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            bottom: BorderSide(
              color:
                  (isDark
                          ? DesignTokens.paperLineDark
                          : DesignTokens.paperLineLight)
                      .withValues(alpha: Alpha.divider),
              width: 0.5,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.s2, 0, Space.s2, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (canPop) const FixoBackButton() else const SizedBox(width: Space.s3),
              if (leading != null) ...[leading!, const SizedBox(width: Space.s2_5)],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: subtitle == null ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: DesignTokens.fontDisplay,
                            fontWeight: FW.bold,
                            fontSize: (title.length > 18 || subtitle != null)
                                ? DesignTokens.fontSizeH2
                                : DesignTokens.fontSizeH1,
                            letterSpacing: Tracking.tight * 20,
                            height: 1.15,
                            color: isDark
                                ? DesignTokens.inkDark
                                : DesignTokens.brand900,
                          ),
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: Space.s0_5),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: DesignTokens.fontBody,
                          fontSize: DesignTokens.fontSizeCaption,
                          color: isDark
                              ? DesignTokens.inkSoftDark
                              : DesignTokens.inkSoftLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
              if (actions.isEmpty) const SizedBox(width: Space.s3),
            ],
          ),
        ),
      ),
    );
  }
}

/// The single back button used by every screen header.
/// iOS chevron, 18px, brand-900/ink-dark — do not fork a second back style.
class FixoBackButton extends StatelessWidget {
  const FixoBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: 'Back',
      onPressed: () => Navigator.of(context).pop(),
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 18,
        color: isDark ? DesignTokens.inkDark : DesignTokens.brand900,
      ),
    );
  }
}

/// Light-blue abstract header background shared by [FixoGradientAppBar] and
/// the home-screen top areas ([FixoGradientTopArea]).
///
/// A pale brand-tinted wash with soft blurred blobs (same language as the
/// onboarding art, but static — headers never animate). Every color derives
/// from the brand hue knob so white-label re-theming still applies.
/// Content paints on top via [child]; blobs stretch to whatever height the
/// header ends up (64px bar or home brand row, status-bar padding included).
class FixoHeaderBackground extends StatelessWidget {
  final Widget child;

  const FixoHeaderBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  Widget legacyBackground() {
    final hue = DesignTokens.hue;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1.0, hue, 0.60, 0.91).toColor(),
            HSLColor.fromAHSL(1.0, hue, 0.55, 0.84).toColor(),
          ],
        ),
      ),
      child: CustomPaint(painter: _HeaderBlobsPainter(), child: child),
    );
  }
}

/// Soft abstract blobs for the header background.
/// Brand-300 glow top-right, brand-700 depth bottom-left, whisper of amber
/// bottom-right — all blurred, all translucent.
class _HeaderBlobsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    void blob(Offset center, double radius, Color color) {
      paint
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
      canvas.drawCircle(center, radius, paint);
    }

    // Glow — brand300, top-right
    blob(
      Offset(size.width * 0.82, -size.height * 0.25),
      size.width * 0.34,
      DesignTokens.brand300.withValues(alpha: Alpha.borderStrong),
    );
    // Depth — brand700, bottom-left
    blob(
      Offset(size.width * 0.08, size.height * 1.1),
      size.width * 0.28,
      DesignTokens.brand700.withValues(alpha: Alpha.tintSoft),
    );
    // Warmth — amber, bottom-right edge
    blob(
      Offset(size.width * 0.97, size.height * 1.05),
      size.width * 0.16,
      DesignTokens.amber.withValues(alpha: Alpha.tintStrong),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Gradient header — the light-blue abstract counterpart to [FixoAppBar].
///
/// Same contract (64px, title/subtitle/leading/actions, iOS-chevron back),
/// but painted with the wavy [FixoHeaderBackground] and dark-blue
/// foreground content. The background extends through the phone's status
/// bar, and the status icons use the dark style for legibility on the
/// pale wash.
///
/// Use on every screen EXCEPT the homeowner/tradie home screens, which keep
/// their brand headers and instead wrap the top area in [FixoGradientTopArea].
///
/// ```dart
/// Scaffold(
///   appBar: FixoGradientAppBar(title: 'My Jobs', showBack: false),
///   ...
/// )
/// ```
class FixoGradientAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showBack;
  final List<Widget> actions;

  const FixoGradientAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.showBack = true,
    this.actions = const [],
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 72 : 112);

  @override
  Widget build(BuildContext context) {
    return FixoAppBar(
      title: title,
      subtitle: subtitle,
      leading: leading,
      showBack: showBack,
      actions: actions,
    );
  }
}

/// Gradient wash for the home-screen top areas (homeowner + tradie).
///
/// Wraps the brand header row so the light-blue waves fill the phone's
/// status bar and the header behind it — the home equivalent of
/// [FixoGradientAppBar] without replacing the wordmark/avatar header itself.
class FixoGradientTopArea extends StatelessWidget {
  final Widget child;

  const FixoGradientTopArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          (Theme.of(context).brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(statusBarColor: Colors.transparent),
      child: FixoHeaderBackground(
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: child,
        ),
      ),
    );
  }
}

/// Icon button sized for [FixoAppBar] actions — 38×38, subtle outlined circle.
class FixoAppBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const FixoAppBarAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = color ?? DesignTokens.inkSoft(isDark);
    return Padding(
      padding: const EdgeInsets.only(right: Space.s2),
      child: Material(
        color: DesignTokens.surfaceCard(isDark),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: Container(
              width: DesignTokens.targetMinimum,
              height: DesignTokens.targetMinimum,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: DesignTokens.paperLine(isDark),
                ),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

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

      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: DesignTokens.amber,
          foregroundColor: DesignTokens.onAmber,
          minimumSize: const Size(48, DesignTokens.heightPrimary),
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.s4),
          disabledBackgroundColor: DesignTokens.surfaceDisabled(
            Theme.of(context).brightness == Brightness.dark,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DesignTokens.onAmber,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeControl,
                  fontWeight: FW.semibold,
                ),
              ),
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

      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, DesignTokens.heightSecondary),
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: 14),
          foregroundColor: DesignTokens.foregroundBrand(isDark),
          side: BorderSide(
            color: DesignTokens.borderControl(isDark),
            width: DesignTokens.borderWidthFor(isDark),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: DesignTokens.fontSizeControl,
            fontWeight: FW.semibold,
          ),
        ),
      ),
    );
  }
}

/// Tonal action button (V16-07) — mid-blue tint fill, 48px minimum height,
/// 14px radius (radiusControl), icon + 14px/600 body label.
/// Replaces low-contrast text links across card and detail screens.
class FixoTonalButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool fullWidth;
  final double height;
  final double iconSize;

  const FixoTonalButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.fullWidth = false,
    this.height = DesignTokens.targetMinimum,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = onPressed != null && !isLoading;
    final bg = isEnabled
        ? DesignTokens.surfaceTonal(isDark)
        : DesignTokens.surfaceDisabled(isDark);
    final fg = isEnabled
        ? DesignTokens.foregroundTonal(isDark)
        : DesignTokens.foregroundDisabled(isDark);

    Widget content;
    if (isLoading) {
      content = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: fg,
        ),
      );
    } else if (icon != null) {
      content = Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: fg),
          const SizedBox(width: Space.s2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: DesignTokens.fontBody,
                fontSize: DesignTokens.fontSizeSm,
                fontWeight: FW.semibold,
                color: fg,
              ),
            ),
          ),
        ],
      );
    } else {
      content = Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: DesignTokens.fontBody,
          fontSize: DesignTokens.fontSizeSm,
          fontWeight: FW.semibold,
          color: fg,
        ),
      );
    }

    final child = Material(
      color: bg,
      borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: Space.s4),
          alignment: Alignment.center,
          constraints: BoxConstraints(
            minHeight: height,
            minWidth: DesignTokens.targetMinimum,
          ),
          child: content,
        ),
      ),
    );

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: child,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: height,
        minWidth: DesignTokens.targetMinimum,
      ),
      child: child,
    );
  }
}

/// Brand wordmark: "TradieHunter" — "Tradie" in brand-900 (blue),
/// "Hunter" in amber, no trailing dot. Matches mockup headers.
class FixoWordmark extends StatelessWidget {
  final double fontSize;
  final Color? color;

  const FixoWordmark({super.key, this.fontSize = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base =
        color ?? (isDark ? DesignTokens.inkDark : DesignTokens.brand900);
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: DesignTokens.fontDisplay,
          fontWeight: FW.bold,
          fontSize: fontSize,
          letterSpacing: Tracking.tight * fontSize,
          color: base,
        ),
        children: [
          TextSpan(text: 'Tradie'),
          TextSpan(
            text: 'Hunter',
            style: const TextStyle(color: DesignTokens.amber),
          ),
        ],
      ),
    );
  }
}
