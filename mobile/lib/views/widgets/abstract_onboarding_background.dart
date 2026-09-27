import 'dart:ui';

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// Soft, organic mesh backdrop for onboarding illustration panels.
///
/// Replaces the old rigid `Container` (solid brand-100 fill + hard
/// corners) behind each onboarding PNG with two or three softly blurred,
/// layered radial-gradient blobs in brand colors, painted behind the
/// illustration. Still uses only the existing brand palette
/// ([DesignTokens.brand300]/[brand500]/[amber]/[brand100Light]/
/// [brand100Dark]) — no new colors are introduced.
///
/// [seed] shifts the blob positions per slide (e.g. pass the onboarding
/// page index) so consecutive slides don't look identical while the
/// PageView animates between them.
class AbstractOnboardingBackground extends StatelessWidget {
  final Widget child;
  final int seed;
  final EdgeInsetsGeometry padding;

  const AbstractOnboardingBackground({
    super.key,
    required this.child,
    this.seed = 0,
    this.padding = const EdgeInsets.all(DesignTokens.space6),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? DesignTokens.paperDark : DesignTokens.brand100Light.withValues(alpha: 0.35);

    return ClipRRect(
      // Softly rounded, not the sharp DesignTokens.radius corner —
      // intentional for this one organic panel.
      borderRadius: BorderRadius.circular(32),
      child: Container(
        color: isDark ? DesignTokens.paperDark : DesignTokens.paperLight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: base),
            CustomPaint(
              painter: _MeshBlobPainter(isDark: isDark, seed: seed),
            ),
            // Blur the painted blobs into soft, fluid gradients.
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: const SizedBox.expand(),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class _MeshBlobPainter extends CustomPainter {
  final bool isDark;
  final int seed;

  _MeshBlobPainter({required this.isDark, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      DesignTokens.brand300.withValues(alpha: isDark ? 0.30 : 0.45),
      DesignTokens.brand500.withValues(alpha: isDark ? 0.22 : 0.30),
      DesignTokens.amber.withValues(alpha: isDark ? 0.14 : 0.18),
    ];

    // Three deterministic blob positions, offset per [seed] so each
    // onboarding slide reads as a distinct but related mesh.
    final anchors = [
      Offset(size.width * (0.20 + 0.05 * (seed % 3)), size.height * 0.22),
      Offset(size.width * (0.85 - 0.05 * (seed % 2)), size.height * 0.35),
      Offset(size.width * (0.45 + 0.08 * ((seed + 1) % 3)), size.height * 0.85),
    ];

    for (var i = 0; i < anchors.length; i++) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [colors[i], colors[i].withValues(alpha: 0.0)],
        ).createShader(
          Rect.fromCircle(center: anchors[i], radius: size.shortestSide * 0.55),
        );
      canvas.drawCircle(anchors[i], size.shortestSide * 0.55, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshBlobPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.seed != seed;
}
