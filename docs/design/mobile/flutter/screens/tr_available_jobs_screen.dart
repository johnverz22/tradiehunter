// GENERATED from ast/screens.mjs (id: tr_available_jobs, route: /tradie/available-jobs). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../th_widgets.dart';

class TrAvailableJobsScreen extends StatelessWidget {
  const TrAvailableJobsScreen({super.key});

  static const String route = '/tradie/available-jobs';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Available jobs', subtitle: 'Open projects near you'),
      dock: THDock(role: THDockRole.tradie, active: THDockTab.jobs),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THCard(
            padding: Space.s3_5,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start, spacing: Space.s2_5,
                children: [
                  THIcon(Icons.info_outline_rounded, size: 18.0, tone: THTone.brand),
                  Expanded(
                    child: THText('Projects posted by homeowners looking for quotes. Exact street addresses stay hidden until booked.', style: THTextStyle.meta),
                  ),
                ],
              ),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s1_5,
                children: [
                  THBadge('Carpentry', kind: THBadgeKind.brand, icon: Icons.work_rounded),
                  THBadge('Closes in 2 days', kind: THBadgeKind.accent, icon: Icons.schedule_rounded),
                ],
              ),
              const SizedBox(height: 8.0),
              THText('Kitchen renovation', style: THTextStyle.title),
              THText('Papamoa, Tauranga · 4.2 km · 2 quotes in', style: THTextStyle.meta, tone: THTone.soft),
              const SizedBox(height: 8.0),
              THKeyValue('Budget', '\$15,000 – \$25,000', bold: true),
              THKeyValue('Materials', 'Undecided', bold: true, divider: true),
              THKeyValue('Timing', 'Flexible', bold: true, divider: true),
              const SizedBox(height: 8.0),
              THButton(
                label: 'View details & quote',
                kind: THButtonKind.accent,
                size: THButtonSize.sm,
                onPressed: () {},
              ),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s1_5,
                children: [
                  THBadge('Painting', kind: THBadgeKind.brand, icon: Icons.work_rounded),
                  THBadge('Closes in 18 hours', kind: THBadgeKind.accent, icon: Icons.schedule_rounded),
                ],
              ),
              const SizedBox(height: 8.0),
              THText('Exterior house repaint', style: THTextStyle.title),
              THText('Mt Maunganui, Tauranga · 2.1 km · No quotes yet', style: THTextStyle.meta, tone: THTone.soft),
              const SizedBox(height: 8.0),
              THKeyValue('Budget', 'Up to \$12,000', bold: true),
              THKeyValue('Materials', 'Tradie supplies', bold: true, divider: true),
              THKeyValue('Timing', 'Date range', bold: true, divider: true),
              const SizedBox(height: 8.0),
              THButton(
                label: 'View details & quote',
                kind: THButtonKind.secondary,
                size: THButtonSize.sm,
                onPressed: () {},
              ),
            ],
          ),
          ],
        ),
    );
  }
}
