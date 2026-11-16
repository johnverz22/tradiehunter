// GENERATED from ast/screens.mjs (id: tr_job, route: /tradie/jobs/:jobId). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class TrJobScreen extends StatelessWidget {
  const TrJobScreen({super.key});

  static const String route = '/tradie/jobs/:jobId';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Leaking kitchen tap', subtitle: 'Booked · Tue, 10:00 am'),
      dock: THDock(role: THDockRole.tradie, active: THDockTab.jobs),
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
                      THText('Ready to start?', style: THTextStyle.title),
                      THText('Check in when you arrive on site.', style: THTextStyle.meta, tone: THTone.soft),
                    ],
                  ),
                  ),
                  THBadge('Booked', kind: THBadgeKind.ok),
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
                  THAvatar('MR', size: THAvatarSize.sm),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2.0,
                    children: [
                      THText('Mere Rangi', style: THTextStyle.title),
                      THText('14 Marine Parade, Mt Maunganui', style: THTextStyle.meta, tone: THTone.soft),
                    ],
                  ),
                  ),
                  THIconButton(icon: Icons.chat_bubble_rounded, kind: THButtonKind.secondary, semanticLabel: 'chat', onPressed: () {}),
                ],
              ),
            ],
          ),
          const THMapPlaceholder(),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue('Service', 'Plumbing'),
              THKeyValue('Rate', '\$85/hr incl. GST', divider: true),
              THKeyValue('Estimate', 'Confirmed on completion', divider: true),
              THKeyValue('Access', 'Homeowner home all day', divider: true),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              THTimeline(items: [THTimelineItem('Accepted', state: THTimelineState.done, subtitle: 'Yesterday 4:12 pm'), THTimelineItem('Booked', state: THTimelineState.cur, subtitle: 'Tue 10:00 am'), THTimelineItem('Check in', state: THTimelineState.todo), THTimelineItem('Complete and enter hours', state: THTimelineState.todo), THTimelineItem('Paid', state: THTimelineState.todo)]),
            ],
          ),
          THButton(
            label: 'Check in',
            kind: THButtonKind.accent,
            icon: Icons.place_rounded,
            onPressed: () {},
          ),
          THButton(
            label: 'Request extra cost',
            kind: THButtonKind.secondary,
            icon: Icons.add_rounded,
            onPressed: () {},
          ),
          ],
        ),
    );
  }
}
