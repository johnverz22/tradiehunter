// GENERATED from ast/screens.mjs (id: tr_earnings, route: /tradie (earnings)). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class TrEarningsScreen extends StatelessWidget {
  const TrEarningsScreen({super.key});

  static const String route = '/tradie (earnings)';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      dock: THDock(role: THDockRole.tradie, active: THDockTab.profile),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THText('Earnings', style: THTextStyle.h1),
          THHero(
            children: [
              THText('NET THIS WEEK', style: THTextStyle.label, tone: THTone.gold),
              const SizedBox(height: 6.0),
              THText('\$1,284.50', style: THTextStyle.moneyLg, tone: THTone.onHero),
              THText('3 jobs · paid on completion', style: THTextStyle.meta, tone: THTone.onHeroSoft),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              THBars(values: [40, 65, 30, 90, 55, 100, 20], labels: ['M', 'T', 'W', 'T', 'F', 'S', 'S']),
            ],
          ),
          THText('Recent payouts', style: THTextStyle.title),
          THCard(
            padding: Space.s1,
            children: [
              THListRow(icon: Icons.attach_money_rounded, title: 'Leaking kitchen tap', subtitle: 'Paid · \$239.75', flat: true),
              THListRow(icon: Icons.attach_money_rounded, title: 'Gas hob install', subtitle: 'Paid · \$412.00', flat: true, divider: true),
              THListRow(icon: Icons.schedule_rounded, title: 'Repaint hallway', subtitle: 'Awaiting payment · \$380.00', flat: true, divider: true),
            ],
          ),
          ],
        ),
    );
  }
}
