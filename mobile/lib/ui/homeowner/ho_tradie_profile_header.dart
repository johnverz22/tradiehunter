import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'ho_tradie_profile_mapper.dart';

class ThProfileHeader extends StatelessWidget {
  const ThProfileHeader({
    super.key,
    required this.profile,
    this.jobEntry,
    this.isTradie = true,
  });

  final UserProfile? profile;
  final TradieListEntry? jobEntry;
  final bool isTradie;

  @override
  Widget build(BuildContext context) {
    final stats = thProfileStats(profile: profile, jobEntry: jobEntry);
    final statsLine = thProfileStatsLine(profile: profile, jobEntry: jobEntry);
    final memberSince = thMemberSince(profile);
    final hasRating = thHasRating(profile);

    return THHero(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: Space.s3_5,
          children: [
            THAvatar(
              profile?.initials.isNotEmpty == true
                  ? profile!.initials
                  : (isTradie ? 'T' : 'H'),
              size: THAvatarSize.lg,
              inverse: true,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.s1_5,
                children: [
                  THText(
                    thProfileName(profile),
                    style: THTextStyle.h2,
                    tone: THTone.onHero,
                  ),
                  THText(
                    thProfileSubtitle(profile, isTradie: isTradie),
                    style: THTextStyle.meta,
                    tone: THTone.onHeroSoft,
                  ),
                  if (isTradie)
                    Wrap(
                      spacing: Space.s2,
                      runSpacing: Space.s2,
                      children: [
                        if (profile?.isVerified == true)
                          const THBadge(
                            'Verified',
                            kind: THBadgeKind.glass,
                            icon: Icons.verified_user_rounded,
                          ),
                        if (profile?.hasInsurance == true)
                          const THBadge('Insured', kind: THBadgeKind.glass),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        if (!hasRating) ...[
          const SizedBox(height: Space.s3),
          const THText(
            'New to Fixo',
            key: Key('profile_new_to_fixo'),
            style: THTextStyle.title,
            tone: THTone.onHero,
          ),
        ],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: Space.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: Space.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      THText(
                        stats[i].value,
                        style: THTextStyle.money,
                        tone: THTone.onHero,
                      ),
                      THText(
                        stats[i].label,
                        style: THTextStyle.meta,
                        tone: THTone.onHeroSoft,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
        if (statsLine != null) ...[
          const SizedBox(height: Space.s3),
          THText(
            statsLine,
            key: const Key('profile_stats_line'),
            style: THTextStyle.meta,
            tone: THTone.onHeroSoft,
          ),
        ],
        if (memberSince != null) ...[
          const SizedBox(height: Space.s1),
          THText(
            memberSince,
            key: const Key('profile_member_since'),
            style: THTextStyle.meta,
            tone: THTone.onHeroSoft,
          ),
        ],
      ],
    );
  }
}
