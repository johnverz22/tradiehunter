// GENERATED from ast/screens.mjs (id: ho_review, route: /jobs/:id/detail (completed)). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoReviewScreen extends StatelessWidget {
  const HoReviewScreen({super.key});

  static const String route = '/jobs/:id/detail (completed)';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'How did it go?', subtitle: 'Aroha Plumbing'),
      stickyBar: THStickyBar(
        children: [
          THButton(
            label: 'Submit review',
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
          const SizedBox(height: 8.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: Space.s3_5,
            children: [
              THAvatar('AP', size: THAvatarSize.lg),
              THText(
                'Job completed',
                style: THTextStyle.h2,
                align: TextAlign.center,
              ),
              THStars(5, size: 36.0),
            ],
          ),
          THField(
            label: 'COMMENT',
            value: 'Arrived on time, quote matched the final bill. Would book again.',
            height: 96.0,
          ),
        ],
      ),
    );
  }
}
