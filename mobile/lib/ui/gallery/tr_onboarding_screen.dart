// GENERATED from ast/screens.mjs (id: tr_onboarding, route: /tradie/onboarding). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class TrOnboardingScreen extends StatelessWidget {
  const TrOnboardingScreen({super.key});

  static const String route = '/tradie/onboarding';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Set up your profile', subtitle: 'Step 2 of 4 · Credentials'),
      stickyBar: THStickyBar(children: [
        THButton(
          label: 'Continue',
          kind: THButtonKind.accent,
          onPressed: () {},
        ),
      ]),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THProgress(steps: 4, done: 1, current: true),
          THField(label: 'LICENCE NUMBER', value: 'PG-482913', icon: Icons.verified_user_rounded),
          THField(label: 'SERVICES AND HOURLY RATE', value: 'Plumbing · \$85/hr', trailing: Icons.chevron_right_rounded),
          THText('DOCUMENTS', style: THTextStyle.label, tone: THTone.soft),
          THCard(
            padding: Space.s1,
            children: [
              THListRow(icon: Icons.description_rounded, title: 'Plumbers licence', subtitle: 'Verified', badge: 'Verified', flat: true),
              THListRow(icon: Icons.description_rounded, title: 'Public liability insurance', subtitle: 'Under review', badge: 'Pending', flat: true, divider: true),
            ],
          ),
          THDashBox(icon: Icons.upload_rounded, title: 'Add another document', subtitle: 'PDF or photo, up to 10 MB'),
          THCard(
            padding: Space.s3_5,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start, spacing: Space.s2_5,
                children: [
                  THIcon(Icons.info_outline_rounded, size: 18.0, tone: THTone.brand),
                  Expanded(
                    child: THText('No call-out fee is charged by TradieHunter. Your rate is shown to homeowners including GST if you are registered.', style: THTextStyle.meta),
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
