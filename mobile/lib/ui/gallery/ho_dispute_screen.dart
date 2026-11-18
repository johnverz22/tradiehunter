// GENERATED from ast/screens.mjs (id: ho_dispute, route: /jobs/:id/dispute). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoDisputeScreen extends StatelessWidget {
  const HoDisputeScreen({super.key});

  static const String route = '/jobs/:id/dispute';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(
        title: 'Dispute amount',
        subtitle: 'Leaking kitchen tap',
      ),
      stickyBar: THStickyBar(
        children: [
          THButton(
            label: 'Submit dispute',
            kind: THButtonKind.danger,
            onPressed: () {},
          ),
        ],
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          THCard(
            tone: THCardTone.accent,
            padding: Space.s3_5,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.s2_5,
                children: [
                  THIcon(
                    Icons.info_outline_rounded,
                    size: 18.0,
                    tone: THTone.accent,
                  ),
                  Expanded(
                    child: THText(
                      'Our team reviews the dispute and evidence from both sides. We will notify you in the app.',
                      style: THTextStyle.meta,
                    ),
                  ),
                ],
              ),
            ],
          ),
          THText('WHAT’S WRONG', style: THTextStyle.label, tone: THTone.soft),
          THPills(
            items: [
              THPillItem('Poor Quality'),
              THPillItem('Damage to Property'),
              THPillItem('Overcharged', selected: true),
              THPillItem('Other'),
            ],
          ),
          THField(
            label: 'DETAILS',
            value: 'Tradie was on site about 1.5 hours, not 2.5.',
            height: 90.0,
          ),
          THDashBox(icon: Icons.photo_camera_rounded, title: 'Add evidence'),
        ],
      ),
    );
  }
}
