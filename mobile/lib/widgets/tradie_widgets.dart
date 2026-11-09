import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'fixo_cards.dart';

/// Avatar circle with initials — brand-500 bg, white text (mockups 05/08/12).
class FixoAvatar extends StatelessWidget {
  final String initials;
  final double radius;

  const FixoAvatar({super.key, required this.initials, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: DesignTokens.brand500,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: DesignTokens.fontDisplay,
          fontWeight: FW.semibold,
          fontSize: radius * 0.7,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Tradie result card from mockup 08-match-result.
class TradieCard extends StatelessWidget {
  final String initials;
  final String name;
  final String trade;
  final bool verified;
  final bool hasInsurance;
  final String distance;
  final double? rating;
  final int? reviewCount;
  final String? bio;

  const TradieCard({
    super.key,
    required this.initials,
    required this.name,
    required this.trade,
    this.verified = false,
    this.hasInsurance = false,
    required this.distance,
    required this.rating,
    required this.reviewCount,
    this.bio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return FixoCard(
      padding: const EdgeInsets.all(Space.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FixoAvatar(
                initials: initials.trim().isEmpty ? '?' : initials,
                radius: 36, // 72px diameter
              ),
              const SizedBox(width: Space.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.trim().isEmpty ? 'Name unavailable' : name,
                      style: TextStyle(
                        fontFamily: DesignTokens.fontDisplay,
                        fontSize: DesignTokens.fontSizeH2,
                        fontWeight: FW.bold,
                        color: DesignTokens.foregroundBrand(isDark),
                      ),
                    ),
                    if (trade.trim().isNotEmpty) ...[
                      const SizedBox(height: Space.s0_5),
                      Text(
                        trade,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (verified || hasInsurance) ...[
                      const SizedBox(height: Space.s2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (verified)
                            _TradieChip(
                              icon: Icons.check_circle_outline,
                              label: 'Verified',
                              color: DesignTokens.inkSuccess(isDark),
                            ),
                          if (hasInsurance)
                            _TradieChip(
                              icon: Icons.shield_outlined,
                              label: 'Insured',
                              color: DesignTokens.foregroundBrand(isDark),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (distance.trim().isNotEmpty)
                Text(distance, style: theme.textTheme.bodyMedium),
              Text(
                (reviewCount == null ||
                        reviewCount == 0 ||
                        rating == null ||
                        rating! <= 0)
                    ? 'New to TradieHunter'
                    : reviewCount != null &&
                            reviewCount! > 0 &&
                            rating != null &&
                            rating! > 0 &&
                            rating! <= 5
                        ? '${rating!.toStringAsFixed(1)} ($reviewCount ${reviewCount == 1 ? 'review' : 'reviews'})'
                        : 'New to TradieHunter',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FW.semibold,
                  color: (reviewCount == null ||
                          reviewCount == 0 ||
                          rating == null ||
                          rating! <= 0)
                      ? DesignTokens.foregroundBrand(isDark)
                      : null,
                ),
              ),
            ],
          ),
          if (bio != null && bio!.trim().isNotEmpty) ...[
            const SizedBox(height: Space.s3),
            Text(
              bio!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small inline badge chip used inside TradieCard.
class _TradieChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TradieChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: Alpha.tintStandard),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: Space.s1),
          Text(
            label,
            style: TextStyle(
              fontSize: DesignTokens.fontSizeCaption,
              fontWeight: FW.semibold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mono stat tile from mockups 09/12 (Jobs / Rating / Response).
class StatCard extends StatelessWidget {
  final String value;
  final String label;

  const StatCard({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: FixoCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: Space.s2),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: DesignTokens.fontMono,
                fontSize: DesignTokens.fontSizeH2,
                fontWeight: FW.semibold,
              ),
            ),
            const SizedBox(height: Space.s1),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
