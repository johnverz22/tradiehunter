// GENERATED from ast/screens.mjs (id: ho_payment_status, route: /jobs/:id/payment/status). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoPaymentStatusScreen extends StatelessWidget {
  const HoPaymentStatusScreen({super.key});

  static const String route = '/jobs/:id/payment/status';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Payment status'),
      stickyBar: THStickyBar(
        children: [
          THButton(
            label: 'Back to job',
            kind: THButtonKind.secondary,
            onPressed: () {},
          ),
        ],
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          const SizedBox(height: 12.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: Space.s3_5,
            children: [
              THTile(Icons.check_rounded, big: true, tone: THBadgeKind.ok),
              THText(
                'Receipt sent for review',
                style: THTextStyle.h1,
                align: TextAlign.center,
              ),
              THText(
                'We usually verify within one business day. You’ll get a notification as soon as it’s done.',
                style: THTextStyle.body,
                tone: THTone.soft,
                align: TextAlign.center,
              ),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue('Amount', '\$261.00', bold: true),
              THKeyValue('Reference', 'TH-4821', bold: true, divider: true),
              THKeyValue(
                'Status',
                'In review',
                badge: THBadgeKind.accent,
                divider: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
