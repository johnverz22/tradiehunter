// GENERATED from ast/screens.mjs (id: ho_home, route: /home). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoHomeScreen extends StatelessWidget {
  const HoHomeScreen({super.key});

  static const String route = '/home';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      dock: THDock(role: THDockRole.homeowner, active: THDockTab.home),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s3,
            children: [
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  THText('Kia ora,', style: THTextStyle.meta, tone: THTone.soft),
                  THText('Mere', style: THTextStyle.h1),
                ],
              ),
              ),
              THIconButton(icon: Icons.notifications_rounded, kind: THButtonKind.secondary, dot: true, semanticLabel: 'bell', onPressed: () {}),
            ],
          ),
          const SizedBox(height: 16.0),
          THHero(
            children: [
              THText('NEEDS YOUR ATTENTION', style: THTextStyle.label, tone: THTone.gold),
              const SizedBox(height: 8.0),
              THText('Approve final amount', style: THTextStyle.h2, tone: THTone.onHero),
              THText('Leaking kitchen tap · Aroha Plumbing', style: THTextStyle.meta, tone: THTone.onHeroSoft),
              const SizedBox(height: 16.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      THText('\$261.00', style: THTextStyle.moneyLg, tone: THTone.onHero),
                      THText('Incl. GST · 2.5 h + 1 extra', style: THTextStyle.meta, tone: THTone.onHeroSoft, size: 11.5),
                    ],
                  ),
                  ),
                  THButton(
                    label: 'Review',
                    kind: THButtonKind.inverse,
                    size: THButtonSize.sm,
                    fullWidth: false,
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          THField(value: 'What needs doing?', icon: Icons.search_rounded, placeholder: true),
          THGrid(
            columns: 4,
            spacing: Space.s2_5,
            children: [
              THTile(Icons.water_drop_rounded, label: 'Plumbing'),
              THTile(Icons.bolt_rounded, label: 'Electrical'),
              THTile(Icons.hardware_rounded, label: 'Carpentry'),
              THTile(Icons.format_paint_rounded, label: 'Painting'),
              THTile(Icons.eco_rounded, label: 'Gardening'),
              THTile(Icons.auto_awesome_rounded, label: 'Cleaning'),
              THTile(Icons.home_rounded, label: 'Roofing'),
              THTile(Icons.more_horiz_rounded, label: 'More'),
            ],
          ),
          const SizedBox(height: 16.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: THText('Active jobs', style: THTextStyle.title),
              ),
              THText('See all', style: THTextStyle.title, tone: THTone.brand, size: 13.0),
            ],
          ),
          const SizedBox(height: 8.0),
          THCard(
            
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s2,
                children: [
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2.0,
                    children: [
                      THText('Repaint hallway', style: THTextStyle.title),
                      THText('Waiting for Kiri Painters', style: THTextStyle.meta, tone: THTone.soft),
                    ],
                  ),
                  ),
                  THBadge('Requested', kind: THBadgeKind.accent),
                ],
              ),
              const SizedBox(height: 12.0),
              THProgress(steps: 5, done: 1, current: true),
            ],
          ),
          const SizedBox(height: 4.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: THText('Top rated near you', style: THTextStyle.title),
              ),
              THText('See all', style: THTextStyle.title, tone: THTone.brand, size: 13.0),
            ],
          ),
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
                  THAvatar('KP', size: THAvatarSize.md),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2.0,
                    children: [
                      THText('Kiri Painters', style: THTextStyle.title),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s1,
                        children: [
                          THIcon(Icons.star_rounded, size: 14.0, tone: THTone.accent),
                          THText('4.8', style: THTextStyle.meta, bold: true),
                          THText('(73) · 4.0 km', style: THTextStyle.meta, tone: THTone.soft),
                        ],
                      ),
                    ],
                  ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      THText('\$70', style: THTextStyle.money),
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
                crossAxisAlignment: CrossAxisAlignment.start, spacing: Space.s2_5,
                children: [
                  THIcon(Icons.info_outline_rounded, size: 18.0, tone: THTone.brand),
                  Expanded(
                    child: THText('Pay only after you approve the final amount. Rates always include GST.', style: THTextStyle.meta),
                  ),
                ],
              ),
            ],
          ),
          ],
        ),
    );
  }
}
