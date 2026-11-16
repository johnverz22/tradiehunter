// GENERATED from ast/screens.mjs (id: tr_extra_cost, route: /tradie/jobs/:jobId (adjustment)). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class TrExtraCostScreen extends StatelessWidget {
  const TrExtraCostScreen({super.key});

  static const String route = '/tradie/jobs/:jobId (adjustment)';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(
        title: 'Request extra cost',
        subtitle: 'Mere must approve before billing',
      ),
      stickyBar: THStickyBar(
        children: [
          THButton(
            label: 'Send request',
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
          THText('TYPE', style: THTextStyle.label, tone: THTone.soft),
          THPills(
            items: [
              THPillItem('Materials', selected: true),
              THPillItem('Extra work'),
              THPillItem('Travel'),
            ],
          ),
          THField(
            label: 'AMOUNT · INCL. GST',
            value: '\$48.50',
            icon: Icons.attach_money_rounded,
          ),
          THField(
            label: 'WHAT IS IT FOR?',
            value: 'Replacement tap cartridge. The old one is worn through.',
            height: 90.0,
          ),
          THDashBox(
            icon: Icons.photo_camera_rounded,
            title: 'Attach receipt or photo',
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
                      'Requests expire after 24 hours. Commission applies to labour only.',
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
