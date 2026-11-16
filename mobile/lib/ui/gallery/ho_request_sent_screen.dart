// GENERATED from ast/screens.mjs (id: ho_request_sent, route: /jobs/:id/request). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoRequestSentScreen extends StatelessWidget {
  const HoRequestSentScreen({super.key});

  static const String route = '/jobs/:id/request';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Request sent'),
      stickyBar: THStickyBar(children: [
        THButton(
          label: 'Cancel request',
          kind: THButtonKind.secondary,
          onPressed: () {},
        ),
      ]),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THRing(value: '14:32', caption: 'left to respond', percent: 0.62),
          THText('Waiting for Aroha Plumbing', style: THTextStyle.h1, align: TextAlign.center),
          THText('If they decline or time runs out, you’ll go back to the list. No charge until the job is approved.', style: THTextStyle.body, tone: THTone.soft, align: TextAlign.center),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue('Rate locked', '\$85/hr incl. GST', bold: true),
              THKeyValue('When', 'Flexible', bold: true, divider: true),
              THKeyValue('Total', 'Confirmed on completion', bold: true, divider: true),
            ],
          ),
          ],
        ),
    );
  }
}
