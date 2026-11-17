// GENERATED from ast/screens.mjs (id: ho_choose_tradie, route: /jobs/:id/tradies). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../th_widgets.dart';

class HoChooseTradieScreen extends StatelessWidget {
  const HoChooseTradieScreen({super.key});

  static const String route = '/jobs/:id/tradies';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Choose a Tradie', subtitle: 'Leaking kitchen tap · Plumbing'),
      stickyBar: THStickyBar(children: [
        THButton(
          label: 'Quick match for me',
          kind: THButtonKind.accent,
          icon: Icons.bolt_rounded,
          onPressed: () {},
        ),
      ]),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THPills(items: [THPillItem('Sort', selected: true, icon: Icons.tune_rounded), THPillItem('Rating'), THPillItem('Distance'), THPillItem('Rate')]),
          THCard(
            padding: Space.s3_5,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s3,
                children: [
                  THAvatar('AP', size: THAvatarSize.md),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2.0,
                    children: [
                      THText('Aroha Plumbing', style: THTextStyle.title),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s1,
                        children: [
                          THIcon(Icons.star_rounded, size: 14.0, tone: THTone.accent),
                          THText('4.9', style: THTextStyle.meta, bold: true),
                          THText('(128) · 2.4 km', style: THTextStyle.meta, tone: THTone.soft),
                        ],
                      ),
                    ],
                  ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      THText('\$85', style: THTextStyle.money),
                      THText('/hr incl. GST', style: THTextStyle.meta, tone: THTone.soft, size: 11.0),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s1_5,
                children: [
                  THBadge('Verified', kind: THBadgeKind.ok, icon: Icons.verified_user_rounded),
                  THBadge('Insured', kind: THBadgeKind.brand),
                  THBadge('Available now', kind: THBadgeKind.accent, dot: true),
                ],
              ),
            ],
          ),
          THCard(
            padding: Space.s3_5,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s3,
                children: [
                  THAvatar('JW', size: THAvatarSize.md),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2.0,
                    children: [
                      THText('Jake’s Plumbing', style: THTextStyle.title),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s1,
                        children: [
                          THIcon(Icons.star_rounded, size: 14.0, tone: THTone.accent),
                          THText('4.8', style: THTextStyle.meta, bold: true),
                          THText('(94) · 3.1 km', style: THTextStyle.meta, tone: THTone.soft),
                        ],
                      ),
                    ],
                  ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      THText('\$79', style: THTextStyle.money),
                      THText('/hr incl. GST', style: THTextStyle.meta, tone: THTone.soft, size: 11.0),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s1_5,
                children: [
                  THBadge('Verified', kind: THBadgeKind.ok, icon: Icons.verified_user_rounded),
                  THBadge('Insured', kind: THBadgeKind.brand),
                  THBadge('Available now', kind: THBadgeKind.accent, dot: true),
                ],
              ),
            ],
          ),
          THCard(
            padding: Space.s3_5,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s3,
                children: [
                  THAvatar('HS', size: THAvatarSize.md),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2.0,
                    children: [
                      THText('Hemi & Sons', style: THTextStyle.title),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s1,
                        children: [
                          THIcon(Icons.star_rounded, size: 14.0, tone: THTone.accent),
                          THText('4.7', style: THTextStyle.meta, bold: true),
                          THText('(61) · 5.6 km', style: THTextStyle.meta, tone: THTone.soft),
                        ],
                      ),
                    ],
                  ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      THText('\$90', style: THTextStyle.money),
                      THText('/hr incl. GST', style: THTextStyle.meta, tone: THTone.soft, size: 11.0),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s1_5,
                children: [
                  THBadge('Verified', kind: THBadgeKind.ok, icon: Icons.verified_user_rounded),
                  THBadge('Insured', kind: THBadgeKind.brand),
                  THBadge('Available now', kind: THBadgeKind.accent, dot: true),
                ],
              ),
            ],
          ),
          ],
        ),
    );
  }
}
