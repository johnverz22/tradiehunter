// GENERATED from ast/screens.mjs (id: ho_choose_tradie, route: /jobs/:id/tradies). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoChooseTradieScreen extends StatelessWidget {
  const HoChooseTradieScreen({super.key});

  static const String route = '/jobs/:id/tradies';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(
        title: 'Choose a Tradie',
        subtitle: 'Leaking kitchen tap · Plumbing',
      ),
      stickyBar: THStickyBar(
        children: [
          THButton(
            label: 'Quick match for me',
            kind: THButtonKind.accent,
            icon: Icons.bolt_rounded,
            onPressed: () {},
          ),
        ],
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          THPills(
            items: [
              THPillItem('Sort', selected: true, icon: Icons.tune_rounded),
              THPillItem('Rating'),
              THPillItem('Distance'),
              THPillItem('Rate'),
            ],
          ),
          _tradieCard('AP', 'Aroha Plumbing', '4.9', '(128) · 2.4 km', '\$85'),
          _tradieCard(
            'JW',
            'Jake\u2019s Plumbing',
            '4.8',
            '(94) · 3.1 km',
            '\$79',
          ),
          _tradieCard('HS', 'Hemi & Sons', '4.7', '(61) · 5.6 km', '\$90'),
        ],
      ),
    );
  }
}

Widget _tradieCard(
  String initials,
  String name,
  String rating,
  String meta,
  String price,
) => THCard(
  padding: Space.s3_5,
  children: [
    Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: Space.s3,
      children: [
        THAvatar(initials, size: THAvatarSize.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 2.0,
            children: [
              THText(name, style: THTextStyle.title),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s1,
                children: [
                  THIcon(Icons.star_rounded, size: 14.0, tone: THTone.accent),
                  THText(rating, style: THTextStyle.meta, bold: true),
                  Flexible(
                    child: THText(
                      meta,
                      style: THTextStyle.meta,
                      tone: THTone.soft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            THText(price, style: THTextStyle.money),
            THText(
              '/hr incl. GST',
              style: THTextStyle.meta,
              tone: THTone.soft,
              size: 11.0,
            ),
          ],
        ),
      ],
    ),
    const SizedBox(height: 10.0),
    Wrap(
      spacing: Space.s1_5,
      runSpacing: Space.s1_5,
      children: [
        THBadge(
          'Verified',
          kind: THBadgeKind.ok,
          icon: Icons.verified_user_rounded,
        ),
        THBadge('Insured', kind: THBadgeKind.brand),
        THBadge('Available now', kind: THBadgeKind.accent, dot: true),
      ],
    ),
  ],
);
