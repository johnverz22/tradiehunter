// GENERATED from ast/screens.mjs (id: tr_home, route: /tradie). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class TrHomeScreen extends StatelessWidget {
  const TrHomeScreen({super.key});

  static const String route = '/tradie';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      dock: THDock(role: THDockRole.tradie, active: THDockTab.home),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          THHero(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s3,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 2.0,
                      children: [
                        THText(
                          'KIA ORA, AROHA',
                          style: THTextStyle.label,
                          tone: THTone.gold,
                        ),
                        THText(
                          'You’re online',
                          style: THTextStyle.h2,
                          tone: THTone.onHero,
                        ),
                      ],
                    ),
                  ),
                  THSwitch(on: true),
                ],
              ),
              const SizedBox(height: 16.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        THText(
                          'Net this week',
                          style: THTextStyle.meta,
                          tone: THTone.onHeroSoft,
                        ),
                        THText(
                          '\$1,284.50',
                          style: THTextStyle.moneyLg,
                          tone: THTone.onHero,
                        ),
                      ],
                    ),
                  ),
                  THBadge(
                    '4.9 · 128',
                    kind: THBadgeKind.glass,
                    icon: Icons.star_rounded,
                  ),
                ],
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: Space.s2_5,
            children: [
              Expanded(
                child: THCard(
                  padding: Space.s3,
                  children: [
                    THText('3', style: THTextStyle.money),
                    THText(
                      'Jobs this week',
                      style: THTextStyle.meta,
                      tone: THTone.soft,
                      size: 12.0,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: THCard(
                  padding: Space.s3,
                  children: [
                    THText('96%', style: THTextStyle.money),
                    THText(
                      'Response rate',
                      style: THTextStyle.meta,
                      tone: THTone.soft,
                      size: 12.0,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: THCard(
                  padding: Space.s3,
                  children: [
                    THText('4.9', style: THTextStyle.money),
                    THText(
                      'Rating',
                      style: THTextStyle.meta,
                      tone: THTone.soft,
                      size: 12.0,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: THText('New leads', style: THTextStyle.title)),
              THBadge('1 new', kind: THBadgeKind.accent),
            ],
          ),
          THCard(
            tone: THCardTone.accent,
            padding: Space.s4,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s2,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 2.0,
                      children: [
                        THText('Leaking kitchen tap', style: THTextStyle.title),
                        THText(
                          'Plumbing · 2.4 km · Flexible',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                  ),
                  THBadge(
                    '09:41 left',
                    kind: THBadgeKind.accent,
                    icon: Icons.schedule_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              THKeyValue('Your rate', '\$85/hr', bold: true),
              THKeyValue('Photos', '3 attached', bold: true, divider: true),
              const SizedBox(height: 8.0),
              THButton(
                label: 'View full request',
                kind: THButtonKind.accent,
                size: THButtonSize.sm,
                onPressed: () {},
              ),
            ],
          ),
          THText('Today', style: THTextStyle.title),
          THCard(
            padding: Space.s1,
            children: [
              THListRow(
                icon: Icons.work_rounded,
                title: 'Gas hob install · Tauranga',
                subtitle: '1:30 pm · Booked',
                flat: true,
              ),
              THListRow(
                icon: Icons.schedule_rounded,
                title: 'Quote visit · Papamoa',
                subtitle: '4:00 pm · Booked',
                flat: true,
                divider: true,
              ),
            ],
          ),
          THText('Needs attention', style: THTextStyle.title),
          THCard(
            padding: Space.s3_5,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s3,
                children: [
                  THAvatar('MR', size: THAvatarSize.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        THText(
                          'Repaint hallway',
                          style: THTextStyle.title,
                          size: 14.5,
                        ),
                        THText(
                          'Awaiting homeowner payment',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                  ),
                  THIcon(Icons.chevron_right_rounded, tone: THTone.soft),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
