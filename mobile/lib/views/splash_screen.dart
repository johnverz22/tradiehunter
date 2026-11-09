import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../theme/design_tokens.dart';
import '../viewmodels/auth_viewmodel.dart';

// ── Splash gradient colours (brand-screen only — always navy, not themed) ───
const _gradientTop    = DesignTokens.brand900;
const _gradientBottom = Color(0xFF2A5A8C); // brand700 lightened for depth — splash-only gradient stop
const _ringColor      = Colors.white;      // opacity controlled per ring

/// S01: full-bleed navy gradient, pulsing concentric rings, wordmark + tagline.
/// Boot logic: first-launch → onboarding, JWT present → fetch role → /home or /tradie.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();

  // Three separate controllers staggered so rings ripple outward.
  late final AnimationController _ring1;
  late final AnimationController _ring2;
  late final AnimationController _ring3;

  @override
  void initState() {
    super.initState();
    _ring1 = _makeRingController(delay: Duration.zero);
    _ring2 = _makeRingController(delay: FixoDurations.splashRing);
    _ring3 = _makeRingController(delay: FixoDurations.splashRingLate);
    _checkAppState();
  }

  AnimationController _makeRingController({required Duration delay}) {
    final ctrl = AnimationController(
      vsync: this,
      duration: FixoDurations.splash,
    );
    Future.delayed(delay, () {
      if (mounted) ctrl.repeat();
    });
    return ctrl;
  }

  @override
  void dispose() {
    _ring1.dispose();
    _ring2.dispose();
    _ring3.dispose();
    super.dispose();
  }

  Future<void> _checkAppState() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

      if (isFirstLaunch) {
        await prefs.setBool('is_first_launch', false);
        if (mounted) context.go('/onboarding');
        return;
      }

      final token = await _storage.read(key: 'jwt_token');
      if (!mounted) return;

      if (token != null) {
        // Role fetch is time-boxed: any failure (offline, stale token, timeout)
        // falls through to /auth rather than stranding the user on splash.
        final destination = await getRoleRoute(
          ref.read(sharedProfileRepositoryProvider),
        ).timeout(const Duration(seconds: 12), onTimeout: () => '/auth');
        if (mounted) context.go(destination);
      } else {
        context.go('/auth');
      }
    } catch (_) {
      if (mounted) context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_gradientTop, _gradientBottom],
          ),
        ),
        child: Stack(
          children: [
            // ── Animated rings — centred in upper ~55% of screen ──────────
            Positioned(
              top: size.height * 0.03,
              left: 0,
              right: 0,
              height: size.height * 0.52,
              child: _PulsingRings(
                controllers: [_ring1, _ring2, _ring3],
              ),
            ),

            // ── Wordmark + rule + tagline — centred ~55% down ─────────────
            Align(
              alignment: const Alignment(0, 0.18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Wordmark
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontFamily: DesignTokens.fontDisplay,
                        fontWeight: FW.bold,
                        fontSize: 40,
                        letterSpacing: Tracking.tight * 40,
                        color: DesignTokens.paperLight,
                      ),
                      children: const [
                        TextSpan(text: 'Tradie'),
                        TextSpan(
                          text: 'Hunter',
                          style: TextStyle(color: DesignTokens.amber),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Space.s3),

                  // Amber rule
                  Container(
                    width: 32,
                    height: 2,
                    decoration: BoxDecoration(
                      color: DesignTokens.amber,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),

                  const SizedBox(height: Space.s3),

                  // Tagline
                  const Text(
                    'Trusted tradies, sorted fast.',
                    style: TextStyle(
                      fontFamily: DesignTokens.fontBody,
                      fontWeight: FW.medium,
                      fontSize: DesignTokens.fontSizeBody,
                      color: DesignTokens.paperLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing rings widget ─────────────────────────────────────────────────────

class _PulsingRings extends StatelessWidget {
  final List<AnimationController> controllers;

  const _PulsingRings({required this.controllers});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(controllers),
      builder: (context, _) {
        return CustomPaint(
          painter: _RingsPainter(
            progresses: controllers.map((c) => c.value).toList(),
          ),
        );
      },
    );
  }
}

class _RingsPainter extends CustomPainter {
  final List<double> progresses; // 0.0 → 1.0 per ring

  _RingsPainter({required this.progresses});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Rings grow from 20% to 90% of the painter's half-width.
    // Opacity fades out as the ring expands (radar pulse feel).
    const minRadiusFraction = 0.20;
    const maxRadiusFraction = 0.90;
    final maxRadius = size.shortestSide / 2 * maxRadiusFraction * 1.6;
    final minRadius = size.shortestSide / 2 * minRadiusFraction * 1.6;

    for (final t in progresses) {
      // Ease-out: rings accelerate out then slow at the edge
      final eased = Curves.easeOut.transform(t);
      final radius = minRadius + (maxRadius - minRadius) * eased;

      // Fade: full opacity in first 20%, then fade to 0
      final opacity = t < 0.2
          ? (t / 0.2) * 0.18        // fade in
          : (1.0 - t) / 0.8 * 0.18; // fade out

      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = _ringColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.progresses != progresses;
}
