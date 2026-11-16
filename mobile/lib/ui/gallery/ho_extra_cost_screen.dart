// GENERATED from ast/screens.mjs (id: ho_extra_cost, route: /jobs/:id/detail (adjustment)). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoExtraCostScreen extends StatelessWidget {
  const HoExtraCostScreen({super.key});

  static const String route = '/jobs/:id/detail (adjustment)';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Leaking kitchen tap', subtitle: 'In progress with Aroha Plumbing'),
      dock: THDock(role: THDockRole.homeowner, active: THDockTab.jobs),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THCard(
            
            children: [
              THProgress(steps: 5, done: 2, current: true),
              const SizedBox(height: 12.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s2,
                children: [
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      THText('Checked in 9:02 am', style: THTextStyle.title),
                      THText('1 h 40 min on site', style: THTextStyle.meta, tone: THTone.soft),
                    ],
                  ),
                  ),
                  THBadge('In progress', kind: THBadgeKind.accent),
                ],
              ),
            ],
          ),
          THCard(
            tone: THCardTone.accent, padding: Space.s4,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  THBadge('Extra cost request', kind: THBadgeKind.accent),
                  THText('22 h left', style: THTextStyle.meta, tone: THTone.soft),
                ],
              ),
              const SizedBox(height: 10.0),
              THText('\$48.50', style: THTextStyle.moneyLg),
              THText('Incl. GST · Materials', style: THTextStyle.meta, tone: THTone.soft),
              const SizedBox(height: 10.0),
              THText('Replacement tap cartridge. The old one is worn through.', style: THTextStyle.body),
              const SizedBox(height: 14.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s2_5,
                children: [
                  Expanded(
                    child: THButton(
                    label: 'Decline',
                    kind: THButtonKind.secondary,
                    size: THButtonSize.sm,
                    onPressed: () {},
                  ),
                  ),
                  Expanded(
                    child: THButton(
                    label: 'Approve',
                    kind: THButtonKind.primary,
                    size: THButtonSize.sm,
                    onPressed: () {},
                  ),
                  ),
                ],
              ),
            ],
          ),
          THText('Nothing is billed until you approve it. Approvals are recorded against the job.', style: THTextStyle.meta, tone: THTone.soft),
          ],
        ),
    );
  }
}
