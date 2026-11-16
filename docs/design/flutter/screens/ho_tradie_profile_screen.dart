// GENERATED from ast/screens.mjs (id: ho_tradie_profile, route: /tradie/:id?jobId=). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../th_widgets.dart';

class HoTradieProfileScreen extends StatelessWidget {
  const HoTradieProfileScreen({super.key});

  static const String route = '/tradie/:id?jobId=';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Profile'),
      stickyBar: THStickyBar(children: [
        THButton(
          label: 'Back',
          kind: THButtonKind.secondary,
          fullWidth: false,
          onPressed: () {},
        ),
        Expanded(
          child: THButton(
          label: 'Request this tradie',
          kind: THButtonKind.accent,
          onPressed: () {},
        ),
        ),
      ]),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THHero(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s3_5,
                children: [
                  THAvatar('AP', size: THAvatarSize.lg, inverse: true),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, spacing: Space.s1_5,
                    children: [
                      THText('Aroha Plumbing', style: THTextStyle.h2, tone: THTone.onHero),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s1_5,
                        children: [
                          THBadge('Verified', kind: THBadgeKind.glass, icon: Icons.verified_user_rounded),
                          THBadge('Insured', kind: THBadgeKind.glass),
                        ],
                      ),
                    ],
                  ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      THText('4.9', style: THTextStyle.money, tone: THTone.onHero),
                      THText('128 reviews', style: THTextStyle.meta, tone: THTone.onHeroSoft, size: 11.5),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      THText('2.4 km', style: THTextStyle.money, tone: THTone.onHero),
                      THText('Away', style: THTextStyle.meta, tone: THTone.onHeroSoft, size: 11.5),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      THText('6 yrs', style: THTextStyle.money, tone: THTone.onHero),
                      THText('Experience', style: THTextStyle.meta, tone: THTone.onHeroSoft, size: 11.5),
                    ],
                  ),
                ],
              ),
            ],
          ),
          THText('Services and rates', style: THTextStyle.title),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue('Plumbing', '\$85/hr', bold: true),
              THKeyValue('Gas fitting', '\$95/hr', bold: true, divider: true),
              THKeyValue('Rate is locked when you request', 'Incl. GST', badge: THBadgeKind.brand, divider: true),
            ],
          ),
          THText('Licences and insurance', style: THTextStyle.title),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue('Plumbers licence', 'Verified', badge: THBadgeKind.ok),
              THKeyValue('Public liability', 'Current', badge: THBadgeKind.ok, divider: true),
            ],
          ),
          ],
        ),
    );
  }
}
