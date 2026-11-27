// GENERATED from ast/screens.mjs (id: ho_quote_detail, route: /jobs/:id/quotes (View quote sheet)). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoQuoteDetailScreen extends StatelessWidget {
  const HoQuoteDetailScreen({super.key});

  static const String route = '/jobs/:id/quotes (View quote sheet)';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Quote', subtitle: 'Kitchen renovation'),
      stickyBar: THStickyBar(
        children: [
          THButton(
            label: 'Accept quote',
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
          THCard(
            padding: Space.s4,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s3,
                children: [
                  THAvatar('BB', size: THAvatarSize.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 2.0,
                      children: [
                        THText('Bay Builders', style: THTextStyle.title),
                        THText(
                          '4.9 · 38 reviews',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                  ),
                  THBadge(
                    'Verified',
                    kind: THBadgeKind.ok,
                    icon: Icons.verified_user_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              THText('\$18,400', style: THTextStyle.money),
              THText('Incl. GST', style: THTextStyle.meta, tone: THTone.soft),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue(
                'Includes',
                'Cabinets, benchtop, splashback, install',
                bold: true,
              ),
              THKeyValue(
                'Does not include',
                'Appliances, plumbing',
                bold: true,
                divider: true,
              ),
              THKeyValue('Materials', 'Included', bold: true, divider: true),
              THKeyValue(
                'Proposed start',
                'Mon 14 Dec',
                bold: true,
                divider: true,
              ),
              THKeyValue(
                'Estimated duration',
                '6 weeks',
                bold: true,
                divider: true,
              ),
              THKeyValue('Valid until', 'Tue 1 Dec', bold: true, divider: true),
            ],
          ),
        ],
      ),
    );
  }
}
