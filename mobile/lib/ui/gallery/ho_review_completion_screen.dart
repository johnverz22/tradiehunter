// GENERATED from ast/screens.mjs (id: ho_review_completion, route: /jobs/:id/detail (awaiting confirmation)). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoReviewCompletionScreen extends StatelessWidget {
  const HoReviewCompletionScreen({super.key});

  static const String route = '/jobs/:id/detail (awaiting confirmation)';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Job complete?', subtitle: 'Aroha Plumbing finished the work'),
      stickyBar: THStickyBar(children: [
        THButton(
          label: 'Dispute',
          kind: THButtonKind.secondary,
          fullWidth: false,
          onPressed: () {},
        ),
        Expanded(
          child: THButton(
          label: 'Approve \$261.00',
          kind: THButtonKind.accent,
          onPressed: () {},
        ),
        ),
      ]),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THHero(
            children: [
              THText('FINAL AMOUNT', style: THTextStyle.label, tone: THTone.gold),
              const SizedBox(height: 6.0),
              THText('\$261.00', style: THTextStyle.moneyLg, tone: THTone.onHero),
              THText('NZD · incl. GST', style: THTextStyle.meta, tone: THTone.onHeroSoft),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              THText('How it adds up', style: THTextStyle.title),
              const SizedBox(height: 4.0),
              THKeyValue('Labour · 2.5 h × \$85', '\$212.50', bold: true),
              THKeyValue('Approved extras (1)', '\$48.50', bold: true, divider: true),
              THKeyValue('Total', '\$261.00', bold: true, strong: true, divider: true),
            ],
          ),
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
                      THText('Hours entered by your tradie. Dispute if this looks wrong.', style: THTextStyle.meta, tone: THTone.soft),
                    ],
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
