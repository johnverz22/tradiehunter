// GENERATED from ast/screens.mjs (id: tr_lead, route: /tradie/requests/:requestId). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class TrLeadScreen extends StatelessWidget {
  const TrLeadScreen({super.key});

  static const String route = '/tradie/requests/:requestId';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(
        title: 'New request',
        subtitle: 'Received 2 min ago · Job #TH-4821',
      ),
      stickyBar: THStickyBar(
        children: [
          THButton(
            label: 'Decline',
            kind: THButtonKind.secondary,
            fullWidth: false,
            onPressed: () {},
          ),
          Expanded(
            child: THButton(
              label: 'Accept job',
              kind: THButtonKind.accent,
              onPressed: () {},
            ),
          ),
        ],
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          THHero(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: THText(
                      'OFFER EXPIRES IN',
                      style: THTextStyle.label,
                      tone: THTone.gold,
                    ),
                  ),
                  THBadge('Quick job', kind: THBadgeKind.glass),
                ],
              ),
              const SizedBox(height: 6.0),
              THText('09:41', style: THTextStyle.moneyLg, tone: THTone.onHero),
              THText(
                'Online tradies get offers first. If you don’t respond, it goes to the next tradie.',
                style: THTextStyle.meta,
                tone: THTone.onHeroSoft,
              ),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              Wrap(
                spacing: Space.s1_5,
                runSpacing: Space.s1_5,
                children: [
                  THBadge(
                    'Plumbing',
                    kind: THBadgeKind.brand,
                    icon: Icons.water_drop_rounded,
                  ),
                  THBadge(
                    'Flexible timing',
                    kind: THBadgeKind.accent,
                    icon: Icons.calendar_today_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              THText('Leaking kitchen tap', style: THTextStyle.h2),
              const SizedBox(height: 6.0),
              THText(
                'Drips constantly, worse when the hot water is on. Water pools under the sink after a few hours. Isolation valve is in the cupboard on the left. Dog is friendly.',
                style: THTextStyle.body,
                tone: THTone.soft,
              ),
            ],
          ),
          THText('Photos from the homeowner', style: THTextStyle.title),
          THPhotoStrip(count: 3),
          THText('Location', style: THTextStyle.title),
          const THMapPlaceholder(),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue('Area', 'Mt Maunganui, Tauranga', bold: true),
              THKeyValue(
                'Distance',
                '2.4 km · about 6 min drive',
                bold: true,
                divider: true,
              ),
              THKeyValue(
                'Exact address',
                'Shared after you accept',
                badge: THBadgeKind.brand,
                divider: true,
              ),
            ],
          ),
          THText('Timing and scope', style: THTextStyle.title),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue('Preferred time', 'Flexible', bold: true),
              THKeyValue(
                'Estimated hours',
                'Not set by homeowner',
                bold: true,
                divider: true,
              ),
              THKeyValue(
                'Job type',
                'Hourly · quick job',
                bold: true,
                divider: true,
              ),
              THKeyValue(
                'Access',
                'Homeowner home all day',
                bold: true,
                divider: true,
              ),
            ],
          ),
          THText('Homeowner', style: THTextStyle.title),
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
                      spacing: 2.0,
                      children: [
                        THText('Mere R.', style: THTextStyle.title),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: Space.s1,
                          children: [
                            THIcon(
                              Icons.star_rounded,
                              size: 14.0,
                              tone: THTone.accent,
                            ),
                            Flexible(
                              child: THText(
                                '4.8 · 12 jobs posted',
                                style: THTextStyle.meta,
                                tone: THTone.soft,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  THBadge(
                    'Email verified',
                    kind: THBadgeKind.ok,
                    icon: Icons.check_rounded,
                  ),
                ],
              ),
            ],
          ),
          THText('What you’ll earn', style: THTextStyle.title),
          THCard(
            tone: THCardTone.accent,
            padding: Space.s4,
            children: [
              THKeyValue('Your rate (locked)', '\$85/hr incl. GST', bold: true),
              THKeyValue(
                'Commission (sample 10%, labour only)',
                '−\$8.50/hr',
                bold: true,
                divider: true,
              ),
              THKeyValue(
                'You keep',
                '\$76.50/hr',
                bold: true,
                strong: true,
                divider: true,
              ),
              const SizedBox(height: 8.0),
              THText(
                'Final amount = confirmed hours × your rate + approved extras. Paid by bank transfer after the homeowner approves.',
                style: THTextStyle.meta,
                tone: THTone.soft,
              ),
            ],
          ),
          THText('What happens next', style: THTextStyle.title),
          THCard(
            padding: Space.s4,
            children: [
              THTimeline(
                items: [
                  THTimelineItem(
                    'Accept this job',
                    state: THTimelineState.cur,
                    subtitle: 'Rate and timing are locked for both sides',
                  ),
                  THTimelineItem(
                    'Agree a time in chat',
                    state: THTimelineState.todo,
                    subtitle: 'Exact address is shared',
                  ),
                  THTimelineItem(
                    'Check in on site',
                    state: THTimelineState.todo,
                    subtitle: 'Hours are recorded as a reference',
                  ),
                  THTimelineItem(
                    'Complete and enter final hours',
                    state: THTimelineState.todo,
                    subtitle: 'Request any extra costs first',
                  ),
                  THTimelineItem(
                    'Homeowner approves and pays',
                    state: THTimelineState.todo,
                    subtitle: 'You are paid after staff verify the receipt',
                  ),
                ],
              ),
            ],
          ),
          THCard(
            padding: Space.s3_5,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.s2_5,
                children: [
                  THIcon(
                    Icons.info_outline_rounded,
                    size: 18.0,
                    tone: THTone.brand,
                  ),
                  Expanded(
                    child: THText(
                      'Declining does not affect your rating. You can turn off leads any time with the online switch.',
                      style: THTextStyle.meta,
                    ),
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
