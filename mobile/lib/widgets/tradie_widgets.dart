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
          fontWeight: FontWeight.w600,
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
  final String distance;
  final double rating;
  final int reviewCount;
  final String? bio;

  const TradieCard({
    super.key,
    required this.initials,
    required this.name,
    required this.trade,
    this.verified = true,
    required this.distance,
    required this.rating,
    required this.reviewCount,
    this.bio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FixoCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FixoAvatar(initials: initials, radius: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(trade,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    if (verified)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('✓ Verified',
                            style: TextStyle(
                                color: DesignTokens.green,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Text(distance,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.star,
                  size: 16, color: DesignTokens.amberDark),
              const SizedBox(width: 4),
              Text('$rating ($reviewCount)',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          if (bio != null) ...[
            const SizedBox(height: 12),
            Text(bio!,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                  fontFamily: DesignTokens.fontMono,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 4),
            Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
