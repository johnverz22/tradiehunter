// GENERATED from ast/screens.mjs (id: ho_quotes, route: /jobs/:id/quotes). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoQuotesScreen extends StatelessWidget {
  const HoQuotesScreen({super.key});

  static const String route = '/jobs/:id/quotes';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(
        title: 'Quotes',
        subtitle: 'Kitchen renovation · 2 of 3 received',
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: Space.s1,
                          children: [
                            THIcon(
                              Icons.star_rounded,
                              size: 14.0,
                              tone: THTone.accent,
                            ),
                            Flexible(
                              child: THText(
                                '4.9 · 6 weeks',
                                style: THTextStyle.meta,
                                tone: THTone.soft,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      THText('\$18,400', style: THTextStyle.money),
                      THText(
                        'fixed · incl. GST',
                        style: THTextStyle.meta,
                        tone: THTone.soft,
                        size: 11.0,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s2_5,
                children: [
                  Expanded(
                    child: THButton(
                      label: 'View quote',
                      kind: THButtonKind.secondary,
                      size: THButtonSize.sm,
                      onPressed: () {},
                    ),
                  ),
                  Expanded(
                    child: THButton(
                      label: 'Accept',
                      kind: THButtonKind.primary,
                      size: THButtonSize.sm,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s3,
                children: [
                  THAvatar('KC', size: THAvatarSize.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 2.0,
                      children: [
                        THText('Kauri Carpentry', style: THTextStyle.title),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: Space.s1,
                          children: [
                            THIcon(
                              Icons.star_rounded,
                              size: 14.0,
                              tone: THTone.accent,
                            ),
                            Flexible(
                              child: THText(
                                '4.7 · 8 weeks',
                                style: THTextStyle.meta,
                                tone: THTone.soft,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      THText('\$21,250', style: THTextStyle.money),
                      THText(
                        'fixed · incl. GST',
                        style: THTextStyle.meta,
                        tone: THTone.soft,
                        size: 11.0,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s2_5,
                children: [
                  Expanded(
                    child: THButton(
                      label: 'View quote',
                      kind: THButtonKind.secondary,
                      size: THButtonSize.sm,
                      onPressed: () {},
                    ),
                  ),
                  Expanded(
                    child: THButton(
                      label: 'Accept',
                      kind: THButtonKind.primary,
                      size: THButtonSize.sm,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
          THCard(
            padding: Space.s4,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s3,
                children: [
                  THAvatar('RB', size: THAvatarSize.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 2.0,
                      children: [
                        THText('Rata Builders', style: THTextStyle.title),
                        THText(
                          'Preparing a quote…',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                  ),
                  THBadge('Pending', kind: THBadgeKind.accent),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
