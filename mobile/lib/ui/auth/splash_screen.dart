// ThSplashScreen: v2 splash (migration plan 3.2, id `splash`).
//
// Hand-owned port of views/splash_screen.dart. Identical boot logic
// (first-launch → onboarding; JWT → role route; 2s delay; 12s role timeout)
// and the same hero + pulsing-ring feel, painted with TH tokens. Class is
// named ThSplashScreen so the router can import v1 and v2 side by side.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';

class ThSplashScreen extends ConsumerStatefulWidget {
  const ThSplashScreen({super.key});

  @override
  ConsumerState<ThSplashScreen> createState() => _ThSplashScreenState();
}

class _ThSplashScreenState extends ConsumerState<ThSplashScreen>
    with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();

  // Three separate controllers staggered so rings ripple outward.
  late AnimationController _ring1;
  late AnimationController _ring2;
  late AnimationController _ring3;
  bool _ringsInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ringsInitialized) return;
    _ringsInitialized = true;
    _ring1 = _makeRingController(delay: Duration.zero);
    _ring2 = _makeRingController(delay: THMotion.splashRingStagger);
    _ring3 = _makeRingController(delay: THMotion.splashRingLate);
  }

  AnimationController _makeRingController({required Duration delay}) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final ctrl = AnimationController(
      vsync: this,
      duration: THMotion.duration(context, THMotion.splashCycle),
    );
    if (!reduceMotion) {
      Future.delayed(THMotion.duration(context, delay), () {
        if (mounted) ctrl.repeat();
      });
    }
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
      await Future.delayed(THDurations.splashIntro);
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
        // Role fetch is time-boxed: any failure (offline, stale token,
        // timeout) falls through to /auth rather than stranding the user.
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

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          final c = context.th;
          return Scaffold(
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.heroStart, c.heroEnd],
                ),
              ),
              child: Stack(
                children: [
                  // Pulsing rings — centred in the upper half of the screen.
                  Positioned(
                    top: size.height * 0.03,
                    left: 0,
                    right: 0,
                    height: size.height * 0.52,
                    child: _ThPulsingRings(
                      controllers: [_ring1, _ring2, _ring3],
                      color: c.onHero,
                    ),
                  ),
                  // Wordmark + rule + tagline — centred ~55% down.
                  Align(
                    alignment: const Alignment(0, 0.18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ThBrandMark(onDark: true),
                        const SizedBox(height: Space.s3),
                        THWordmark(large: true),
                        const SizedBox(height: Space.s3),
                        // Amber rule
                        Container(
                          width: Space.s8,
                          height: 2,
                          decoration: BoxDecoration(
                            color: c.heroGold,
                            borderRadius: BorderRadius.circular(Radii.hairline),
                          ),
                        ),
                        const SizedBox(height: Space.s3),
                        Text(
                          'Trusted tradies, sorted fast.',
                          style: THType.body.copyWith(
                            fontWeight: FW.medium,
                            color: c.onHero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThPulsingRings extends StatelessWidget {
  final List<AnimationController> controllers;
  final Color color;

  const _ThPulsingRings({required this.controllers, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(controllers),
      builder: (context, _) {
        return CustomPaint(
          painter: _ThRingsPainter(
            progresses: controllers.map((c) => c.value).toList(),
            color: color,
          ),
        );
      },
    );
  }
}

class _ThRingsPainter extends CustomPainter {
  final List<double> progresses; // 0.0 → 1.0 per ring
  final Color color;

  _ThRingsPainter({required this.progresses, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Rings grow from 20% to 90% of the painter's half-width; opacity fades
    // out as the ring expands (radar pulse feel).
    const minRadiusFraction = 0.20;
    const maxRadiusFraction = 0.90;
    final maxRadius = size.shortestSide / 2 * maxRadiusFraction * 1.6;
    final minRadius = size.shortestSide / 2 * minRadiusFraction * 1.6;

    for (final t in progresses) {
      final eased = THMotion.splashCurve.transform(t);
      final radius = minRadius + (maxRadius - minRadius) * eased;
      final opacity = t < 0.2 ? (t / 0.2) * 0.18 : (1.0 - t) / 0.8 * 0.18;
      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ThRingsPainter old) =>
      old.progresses != progresses || old.color != color;
}
