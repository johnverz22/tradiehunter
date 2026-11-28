// GENERATED from ast/screens.mjs (id: tr_job_board_detail, route: /tradie/available-jobs/:jobId). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class TrJobBoardDetailScreen extends StatelessWidget {
  const TrJobBoardDetailScreen({super.key});

  static const String route = '/tradie/available-jobs/:jobId';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(
        title: 'Open project',
        subtitle: 'Closes in 2 days · 2 quotes in',
      ),
      stickyBar: THStickyBar(
        children: [
          THButton(
            label: 'Submit quote',
            kind: THButtonKind.accent,
            onPressed: () {},
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
                      'QUOTES CLOSE IN',
                      style: THTextStyle.label,
                      tone: THTone.gold,
                    ),
                  ),
                  THBadge('Open project', kind: THBadgeKind.glass),
                ],
              ),
              const SizedBox(height: 6.0),
              THText('2 days', style: THTextStyle.moneyLg, tone: THTone.onHero),
              THText(
                'Quote valid for 72 hours once submitted.',
                style: THTextStyle.meta,
                tone: THTone.onHeroSoft,
              ),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s1_5,
                children: [
                  THBadge(
                    'Carpentry',
                    kind: THBadgeKind.brand,
                    icon: Icons.work_rounded,
                  ),
                  THBadge(
                    'Flexible timing',
                    kind: THBadgeKind.accent,
                    icon: Icons.calendar_today_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              THText('Kitchen renovation', style: THTextStyle.h2),
              const SizedBox(height: 6.0),
              THText(
                'Full kitchen strip-out and new cabinetry installation. Plumbing and electrical rough-in coordinated separately.',
                style: THTextStyle.body,
                tone: THTone.soft,
              ),
            ],
          ),
          THText('Photos from the homeowner', style: THTextStyle.title),
          THPhotoStrip(count: 3),
          THText('Location', style: THTextStyle.title),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue('Suburb', 'Papamoa, Tauranga', bold: true),
              THKeyValue('Distance', '4.2 km away', bold: true, divider: true),
              THKeyValue(
                'Exact address',
                'Shared after you are booked',
                badge: THBadgeKind.brand,
                divider: true,
              ),
            ],
          ),
          THText('Project scope and budget', style: THTextStyle.title),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue('Budget range', '\$15,000 – \$25,000', bold: true),
              THKeyValue('Materials', 'Undecided', bold: true, divider: true),
              THKeyValue(
                'Site visit',
                'Welcome before quoting',
                bold: true,
                divider: true,
              ),
              THKeyValue(
                'Scope notes',
                'Keep existing island footprint.',
                bold: true,
                divider: true,
              ),
              THKeyValue(
                'Preferred timing',
                'Flexible',
                bold: true,
                divider: true,
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
                      'Your quote stays binding once submitted. Any extra costs later require homeowner approval.',
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
