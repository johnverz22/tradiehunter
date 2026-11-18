// GENERATED from ast/screens.mjs (id: ho_post_quick, route: /jobs/new). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../th_widgets.dart';

class HoPostQuickScreen extends StatelessWidget {
  const HoPostQuickScreen({super.key});

  static const String route = '/jobs/new';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Post a Job', subtitle: 'Describe it. No price needed yet.'),
      stickyBar: THStickyBar(children: [
        THButton(
          label: 'Choose a tradie',
          kind: THButtonKind.accent,
          onPressed: () {},
        ),
      ]),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THSegmented(items: ['Quick job · hourly', 'Project'], selected: 0),
          THField(label: 'JOB TITLE', value: 'Leaking kitchen tap'),
          THField(label: 'SERVICE', value: 'Plumbing', trailing: Icons.chevron_right_rounded),
          THField(label: 'DESCRIPTION', value: 'Drips constantly, worse when hot water is on.', height: 78.0),
          THText('WHEN', style: THTextStyle.label, tone: THTone.soft),
          THPills(items: [THPillItem('Flexible', selected: true), THPillItem('ASAP'), THPillItem('Pick a date', icon: Icons.calendar_today_rounded), THPillItem('Date range')]),
          THField(label: 'ESTIMATED HOURS · OPTIONAL', value: 'Blank means total is confirmed on completion', placeholder: true),
          THField(label: 'JOB ADDRESS', value: '14 Marine Parade, Mt Maunganui', icon: Icons.place_rounded),
          THDashBox(icon: Icons.photo_camera_rounded, title: 'Add photos'),
          ],
        ),
    );
  }
}
