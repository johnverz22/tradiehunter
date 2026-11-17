// GENERATED from ast/screens.mjs (id: tr_complete, route: /tradie/jobs/:jobId (check-out)). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../th_widgets.dart';

class TrCompleteScreen extends StatelessWidget {
  const TrCompleteScreen({super.key});

  static const String route = '/tradie/jobs/:jobId (check-out)';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Complete job', subtitle: 'Leaking kitchen tap'),
      stickyBar: THStickyBar(children: [
        THButton(
          label: 'Send for approval',
          kind: THButtonKind.accent,
          onPressed: () {},
        ),
      ]),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THCard(
            padding: Space.s4,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s2_5,
                children: [
                  THIcon(Icons.schedule_rounded, tone: THTone.brand),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      THText('On site 9:02 am to 11:34 am', style: THTextStyle.body),
                      THText('2 h 32 min, shown as reference', style: THTextStyle.meta, tone: THTone.soft),
                    ],
                  ),
                  ),
                ],
              ),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              THText('FINAL HOURS', style: THTextStyle.label, tone: THTone.soft),
              const SizedBox(height: 10.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.center, spacing: Space.s3_5,
                children: [
                  THIconButton(icon: Icons.remove_rounded, kind: THButtonKind.secondary, semanticLabel: 'minus', onPressed: () {}),
                  THText('2.5 h', style: THTextStyle.moneyLg),
                  THIconButton(icon: Icons.add_rounded, kind: THButtonKind.secondary, semanticLabel: 'plus', onPressed: () {}),
                ],
              ),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue('Labour · 2.5 h × \$85', '\$212.50', bold: true),
              THKeyValue('Approved extras', '\$48.50', bold: true, divider: true),
              THKeyValue('Homeowner pays', '\$261.00', bold: true, strong: true, divider: true),
            ],
          ),
          THCard(
            tone: THCardTone.accent, padding: Space.s4,
            children: [
              THKeyValue('Commission (sample 10%, labour only)', '−\$21.25', bold: true),
              THKeyValue('You receive', '\$239.75', bold: true, strong: true, divider: true),
            ],
          ),
          ],
        ),
    );
  }
}
