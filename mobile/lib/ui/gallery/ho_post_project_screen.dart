// GENERATED from ast/screens.mjs (id: ho_post_project, route: /jobs/new (project)). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoPostProjectScreen extends StatelessWidget {
  const HoPostProjectScreen({super.key});

  static const String route = '/jobs/new (project)';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Post a Job', subtitle: 'Get up to 3 quotes'),
      stickyBar: THStickyBar(children: [
        THButton(
          label: 'Request up to 3 quotes',
          kind: THButtonKind.accent,
          onPressed: () {},
        ),
      ]),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THSegmented(items: ['Quick job · hourly', 'Project'], selected: 1),
          THField(label: 'PROJECT SUMMARY', value: 'Kitchen renovation'),
          THField(label: 'SERVICE', value: 'Carpentry', trailing: Icons.chevron_right_rounded),
          THField(label: 'SCOPE', value: 'Replace cabinets, benchtop and splashback. Plumbing stays.', height: 78.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s2_5,
            children: [
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  THField(label: 'BUDGET MIN', value: '\$15,000'),
                ],
              ),
              ),
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  THField(label: 'BUDGET MAX', value: '\$25,000'),
                ],
              ),
              ),
            ],
          ),
          THText('WHEN', style: THTextStyle.label, tone: THTone.soft),
          THPills(items: [THPillItem('Flexible', selected: true), THPillItem('Pick a date', icon: Icons.calendar_today_rounded), THPillItem('Date range')]),
          const SizedBox(height: 4.0),
          THCard(
            tone: THCardTone.accent, padding: Space.s3_5,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start, spacing: Space.s2_5,
                children: [
                  THIcon(Icons.info_outline_rounded, size: 18.0, tone: THTone.accent),
                  Expanded(
                    child: THText('Jobs over \$30,000 need a written contract. Milestone payments are not available yet.', style: THTextStyle.meta),
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
