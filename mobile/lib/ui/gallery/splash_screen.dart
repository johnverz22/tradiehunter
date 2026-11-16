// GENERATED from ast/screens.mjs (id: splash, route: /). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const String route = '/';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      heroBackground: true,
      scrollable: false,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s4,
            children: [
              THWordmark(large: true),
              THText('Trusted tradies, sorted fast.', style: THTextStyle.body, tone: THTone.onHero),
            ],
          ),
          const Spacer(),
          ],
        ),
    );
  }
}
