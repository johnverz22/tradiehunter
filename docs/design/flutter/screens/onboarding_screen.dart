// GENERATED from ast/screens.mjs (id: onboarding, route: /onboarding). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../th_widgets.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const String route = '/onboarding';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      scrollable: false,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THIllustration(Icons.search_rounded),
          const SizedBox(height: 24.0),
          THText('Post a job in minutes', style: THTextStyle.h1),
          const SizedBox(height: 8.0),
          THText('Describe what you need, choose a local tradie, and pay only when the work is approved.', style: THTextStyle.body, tone: THTone.soft),
          const Spacer(),
          THDots(count: 3, on: 0),
          const SizedBox(height: 20.0),
          THButton(
            label: 'Next',
            kind: THButtonKind.primary,
            onPressed: () {},
          ),
          THButton(
            label: 'Skip',
            kind: THButtonKind.ghost,
            onPressed: () {},
          ),
          ],
        ),
    );
  }
}
