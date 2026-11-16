// GENERATED from ast/screens.mjs (id: ho_job_booked, route: /jobs/:id/detail). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoJobBookedScreen extends StatelessWidget {
  const HoJobBookedScreen({super.key});

  static const String route = '/jobs/:id/detail';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Leaking kitchen tap', subtitle: 'Booked'),
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
                      THText('Booked for Tue, 10:00 am', style: THTextStyle.title),
                      THText('Aroha Plumbing will check in on arrival.', style: THTextStyle.meta, tone: THTone.soft),
                    ],
                  ),
                  ),
                  THBadge('Booked', kind: THBadgeKind.ok),
                ],
              ),
            ],
          ),
          THCard(
            
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
                      THText('\$85/hr incl. GST · locked', style: THTextStyle.meta, tone: THTone.soft),
                    ],
                  ),
                  ),
                  THIconButton(icon: Icons.chat_bubble_rounded, kind: THButtonKind.secondary, semanticLabel: 'chat', onPressed: () {}),
                ],
              ),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue('Service', 'Plumbing'),
              THKeyValue('Address', '14 Marine Parade', divider: true),
              THKeyValue('Timing', 'Flexible', divider: true),
              THKeyValue('Estimate', 'Confirmed on completion', divider: true),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              THTimeline(items: [THTimelineItem('Request accepted', state: THTimelineState.done, subtitle: 'Aroha Plumbing · yesterday 4:12 pm'), THTimelineItem('Booked', state: THTimelineState.cur, subtitle: 'Tue 10:00 am'), THTimelineItem('Check-in on site', state: THTimelineState.todo), THTimelineItem('Work complete and hours entered', state: THTimelineState.todo), THTimelineItem('Approve final amount and pay', state: THTimelineState.todo)]),
            ],
          ),
          THButton(
            label: 'Message Aroha',
            kind: THButtonKind.primary,
            icon: Icons.chat_bubble_rounded,
            onPressed: () {},
          ),
          THButton(
            label: 'Cancel job',
            kind: THButtonKind.ghost,
            onPressed: () {},
          ),
          ],
        ),
    );
  }
}
