import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../theme/design_tokens.dart';
import '../../theme/fixo_theme.dart';

class HomeownerDashboardHeader extends StatelessWidget {
  final String firstName;
  final String? location;
  final DateTime now;
  final Widget? child;

  const HomeownerDashboardHeader({
    super.key,
    required this.firstName,
    required this.now,
    this.location,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final greeting = now.hour < 12
        ? 'GOOD MORNING'
        : now.hour < 18
        ? 'GOOD AFTERNOON'
        : 'GOOD EVENING';
    return Container(
      key: const Key('homeowner_hero'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [THColors.light.brand, DesignTokens.brand700]
              : [THColors.light.brand, DesignTokens.brand500],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _BlueprintDots(dark)),
            ),
          ),
          Positioned(
            right: -50,
            top: -30,
            child: Opacity(
              opacity: 0.22,
              child: Image.asset(
                'assets/illustrations/rings-3-navy.png',
                width: 260,
                excludeFromSemantics: true,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s4, Space.gutter, Space.s7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeSecondary,
                                letterSpacing: Tracking.emphasis,
                                color: Colors.white.withValues(alpha: Alpha.textOnGradient),
                              ),
                            ),
                            const SizedBox(height: Space.s1),
                            Text(
                              firstName.isEmpty ? 'Welcome back' : firstName,
                              style: const TextStyle(
                                fontFamily: TypeTokens.fontDisplay,
                                fontSize: 28,
                                fontWeight: FW.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (location != null &&
                                location!.trim().isNotEmpty) ...[
                              const SizedBox(height: Space.s3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: Alpha.tintMid),
                                  borderRadius: BorderRadius.circular(
                                    Radii.pill,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: Space.s1),
                                    Flexible(
                                      child: Text(
                                        location!,
                                        style: const TextStyle(
                                          fontSize: DesignTokens.fontSizeCaption,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Notifications',
                        constraints: const BoxConstraints(
                          minWidth: Sizes.tapMin,
                          minHeight: Sizes.tapMin,
                        ),
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Notifications'),
                            content: const Text(
                              'Job updates appear on your dashboard. Push notifications are delivered to your device when enabled.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  ?child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlueprintDots extends CustomPainter {
  final bool dark;
  const _BlueprintDots(this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? THColors.dark.brand : THColors.light.brand).withValues(
        alpha: dark ? 0.042 : 0.03,
      );
    for (double x = 12; x < size.width; x += 24) {
      for (double y = 12; y < size.height; y += 24) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BlueprintDots oldDelegate) => dark != oldDelegate.dark;
}

class HomeownerDashboardEmpty extends StatelessWidget {
  final VoidCallback onPost;
  const HomeownerDashboardEmpty({super.key, required this.onPost});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<THColors>()!;
    final dark = theme.brightness == Brightness.dark;
    Widget stat(String value, String label, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.s2, vertical: Space.s4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: Alpha.tintLight),
          borderRadius: BorderRadius.circular(Radii.tile),
        ),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TypeTokens.fontDisplay,
                fontSize: DesignTokens.fontSizeH2,
                fontWeight: FW.bold,
                color: color,
              ),
            ),
            const SizedBox(height: Space.s1),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: DesignTokens.fontSizeCaption, color: colors.textSoft),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        const SizedBox(height: Space.s6),
        DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: colors.brand.withValues(alpha: Alpha.tintStandard),
                blurRadius: 24,
                offset: const Offset(0, 8),
                blurStyle: BlurStyle.outer,
              ),
            ],
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            'assets/illustrations/il-01-${dark ? 'dark' : 'light'}.png',
            width: 196,
            height: 196,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: Space.s6),
        Text(
          'Find a tradie you can trust',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: DesignTokens.fontSizeH1,
            fontWeight: FW.bold,
          ),
        ),
        const SizedBox(height: Space.s2),
        const Text(
          'Describe your job and get matched with a verified local in minutes.',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.5),
        ),
        const SizedBox(height: Space.s6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stat('<5 min', 'to match', colors.brand),
            const SizedBox(width: Space.s2_5),
            stat('Verified', 'local tradies', colors.success),
            const SizedBox(width: Space.s2_5),
            stat('Hourly', 'rate pricing', colors.accentText),
          ],
        ),
        const SizedBox(height: Space.s6),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onPost,
            icon: const Icon(Icons.add),
            label: const Text('Post a job'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: DesignTokens.onAmber,
              minimumSize: const Size(0, Sizes.button),
              shadowColor: DesignTokens.amber.withValues(alpha: Alpha.shadow),
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }
}

@Preview(name: 'Homeowner hero light', size: Size(402, 240))
Widget homeownerHeroLightPreview() => MaterialApp(
  theme: FixoTheme.light(),
  home: Scaffold(
    body: HomeownerDashboardHeader(
      firstName: 'Sarah',
      now: DateTime(2026, 11, 2, 9),
    ),
  ),
);

@Preview(name: 'Homeowner hero dark', size: Size(402, 240))
Widget homeownerHeroDarkPreview() => MaterialApp(
  theme: FixoTheme.dark(),
  home: Scaffold(
    body: HomeownerDashboardHeader(
      firstName: 'Sarah',
      now: DateTime(2026, 11, 2, 9),
    ),
  ),
);
