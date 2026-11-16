// GENERATED from ast/screens.mjs (id: ho_payment, route: /jobs/:id/payment). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoPaymentScreen extends StatelessWidget {
  const HoPaymentScreen({super.key});

  static const String route = '/jobs/:id/payment';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Payment'),
      stickyBar: THStickyBar(children: [
        THButton(
          label: 'Upload bank receipt',
          kind: THButtonKind.accent,
          onPressed: () {},
        ),
      ]),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THHero(
            children: [
              THText('AMOUNT TO PAY', style: THTextStyle.label, tone: THTone.gold),
              const SizedBox(height: 6.0),
              THText('\$261.00', style: THTextStyle.moneyLg, tone: THTone.onHero),
              THText('NZD · incl. GST', style: THTextStyle.meta, tone: THTone.onHeroSoft),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue('Labour · 2.5 h × \$85', '\$212.50', bold: true),
              THKeyValue('Approved extras', '\$48.50', bold: true, divider: true),
              THKeyValue('Job total', '\$261.00', bold: true, strong: true, divider: true),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue('Account name', 'TradieHunter Ltd', bold: true),
              THKeyValue('Account number', '02-0000-0000000-00', bold: true, divider: true),
              THKeyValue('Reference', 'TH-4821', bold: true, copy: true, divider: true),
            ],
          ),
          THDashBox(icon: Icons.upload_rounded, title: 'Upload your receipt', subtitle: 'Staff verify it, then the job completes'),
          ],
        ),
    );
  }
}
