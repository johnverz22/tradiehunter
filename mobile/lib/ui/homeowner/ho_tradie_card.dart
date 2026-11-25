// HoTradieCard: v2 Choose-a-Tradie row (migration plan 4.1 #4).
//
// Mirrors the v1 H19 card's truthfulness rules: rate omitted when the server
// sent none, GST label from the shared rule, rating only with a real score and
// review count, distance never fabricated. Shared with the later
// browse-tradies port; it takes a TradieListEntry and never talks to a
// repository.
import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'ho_choose_tradie_mapper.dart';

class HoTradieCard extends StatelessWidget {
  const HoTradieCard({super.key, required this.entry, required this.onTap});

  final TradieListEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final score = thTradieScore(entry);
    final distance = thTradieDistanceLine(entry);
    final rate = thTradieRate(entry);
    final fallback = thTradieNoRatingFallback(entry);
    final reviewCount = thTradieReviewCount(entry);

    final meta = score != null
        ? [if (reviewCount.isNotEmpty) reviewCount, distance].join(' · ')
        : '$fallback · $distance';

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isLargeScale = textScale >= 1.3;

    return Semantics(
      button: true,
      label: [
        entry.displayName,
        if (score != null) '$score stars' else fallback,
        distance,
        if (rate != null) rate.amount,
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: THCard(
          padding: Space.s3_5,
          children: [
            if (isLargeScale) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s3,
                children: [
                  THAvatar(
                    entry.initials.isEmpty ? '?' : entry.initials,
                    size: THAvatarSize.md,
                  ),
                  Expanded(
                    child: Text(
                      entry.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: THType.title.copyWith(color: c.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s2),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.s2,
                runSpacing: Space.s1,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (score != null) ...[
                        const THIcon(
                          Icons.star_rounded,
                          size: Sizes.iconSm,
                          tone: THTone.accent,
                        ),
                        const SizedBox(width: Space.s1),
                        Text(
                          score,
                          style: THType.meta.copyWith(
                            color: c.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: Space.s1),
                      ],
                      Text(
                        meta,
                        style: THType.meta.copyWith(color: c.textSoft),
                      ),
                    ],
                  ),
                  if (rate != null)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Space.s1,
                      children: [
                        THText(rate.amount, style: THTextStyle.money),
                        THText(
                          rate.gstNote == null ? '/hr' : '/hr ${rate.gstNote}',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                ],
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s3,
                children: [
                  THAvatar(
                    entry.initials.isEmpty ? '?' : entry.initials,
                    size: THAvatarSize.md,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: Space.s1,
                      children: [
                        // Two lines, not one: at 200% text a one-line ellipsis
                        // cut the name the homeowner is choosing by (H-06).
                        Text(
                          entry.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: THType.title.copyWith(color: c.text),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: Space.s1,
                          children: [
                            if (score != null)
                              const THIcon(
                                Icons.star_rounded,
                                size: Sizes.iconSm,
                                tone: THTone.accent,
                              ),
                            Flexible(
                              child: Text(
                                score ?? meta,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: THType.meta.copyWith(
                                  color: c.text,
                                  fontWeight: score != null
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (score != null)
                              Flexible(
                                child: Text(
                                  meta,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: THType.meta.copyWith(
                                    color: c.textSoft,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (rate != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        THText(rate.amount, style: THTextStyle.money),
                        THText(
                          rate.gstNote == null ? '/hr' : '/hr ${rate.gstNote}',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: Space.s2_5),
            Wrap(
              spacing: Space.s1_5,
              runSpacing: Space.s1_5,
              children: [
                for (final badge in thTradieBadges(entry))
                  THBadge(
                    badge.label,
                    kind: switch (badge.kind) {
                      ThTradieBadgeKind.verified => THBadgeKind.ok,
                      ThTradieBadgeKind.insured => THBadgeKind.brand,
                      ThTradieBadgeKind.available => THBadgeKind.accent,
                    },
                    icon: badge.icon,
                    dot: badge.dot,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
