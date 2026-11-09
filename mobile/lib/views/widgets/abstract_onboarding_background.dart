import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Soft, organic fluid mesh backdrop for the onboarding flow.
///
/// Draws three large radial-gradient blobs (brand300 / amber / brand700,
/// all at low alpha) through an ImageFilter.blur so no hard edges exist.
/// A slow internal AnimationController makes the blobs drift organically.
class AbstractOnboardingBackground extends StatefulWidget {
  final Widget child;
  final int seed;

  const AbstractOnboardingBackground({
    super.key,
    required this.child,
    this.seed = 7,
  });

  @override
  State<AbstractOnboardingBackground> createState() =>
      _AbstractOnboardingBackgroundState();
}

class _AbstractOnboardingBackgroundState
    extends State<AbstractOnboardingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced-motion users keep the static mesh without the ambient drift.
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (animate && !_drift.isAnimating) {
      _drift.repeat();
    } else if (!animate && _drift.isAnimating) {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base wash
        ColoredBox(
          color: isDark ? DesignTokens.paperDark : DesignTokens.paperLight,
        ),
        AnimatedBuilder(
          animation: _drift,
          builder: (context, _) => CustomPaint(
            painter: _MeshPainter(
              progress: _drift.value,
              seed: widget.seed,
              isDark: isDark,
            ),
          ),
        ),
        // Fine-grain frosted veil for extra softness
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: const SizedBox.expand(),
        ),
        widget.child,
      ],
    );
  }
}

class _MeshPainter extends CustomPainter {
  final double progress;
  final int seed;
  final bool isDark;

  _MeshPainter({
    required this.progress,
    required this.seed,
    required this.isDark,
  });

  Offset _orbit(
    double t,
    double cx,
    double cy,
    double rx,
    double ry,
    double phase,
  ) {
    final a = (t * 2 * math.pi) + phase;
    return Offset(cx + rx * math.cos(a), cy + ry * math.sin(a * 0.8 + phase));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final paint = Paint();

    void blob(Offset center, double radius, Color color) {
      paint
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
      canvas.drawCircle(center, radius, paint);
    }

    // Blob A — brand300, top-left
    blob(
      _orbit(
        progress,
        size.width * 0.25,
        size.height * 0.22,
        size.width * 0.06,
        size.height * 0.04,
        rnd.nextDouble() * 6,
      ),
      size.width * 0.45,
      DesignTokens.brand300.withValues(alpha: isDark ? 0.16 : 0.22),
    );
    // Blob B — amber, bottom-right
    blob(
      _orbit(
        progress,
        size.width * 0.78,
        size.height * 0.72,
        size.width * 0.05,
        size.height * 0.05,
        rnd.nextDouble() * 6,
      ),
      size.width * 0.4,
      DesignTokens.amber.withValues(alpha: isDark ? 0.10 : 0.14),
    );
    // Blob C — brand700, center-left depth
    blob(
      _orbit(
        progress,
        size.width * 0.1,
        size.height * 0.6,
        size.width * 0.04,
        size.height * 0.06,
        rnd.nextDouble() * 6,
      ),
      size.width * 0.35,
      DesignTokens.brand700.withValues(alpha: isDark ? 0.12 : 0.08),
    );
  }

  @override
  bool shouldRepaint(_MeshPainter old) =>
      old.progress != progress || old.isDark != isDark;
}
