// GENERATED from ast/screens.mjs (id: role_select, route: /role-select). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../th_widgets.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  static const String route = '/role-select';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      scrollable: false,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          const SizedBox(height: 24.0),
          THText('How will you use TradieHunter?', style: THTextStyle.h1),
          const SizedBox(height: 20.0),
          THCard(
            tone: THCardTone.accent, padding: 18.0,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s3_5,
                children: [
                  THTile(Icons.home_rounded, big: true),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2.0,
                    children: [
                      THText('I need a tradie', style: THTextStyle.title),
                      THText('Post jobs, compare rates, pay after approval.', style: THTextStyle.meta, tone: THTone.soft),
                    ],
                  ),
                  ),
                  THIcon(Icons.check_rounded, tone: THTone.accent),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          THCard(
            padding: 18.0,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s3_5,
                children: [
                  THTile(Icons.hardware_rounded, big: true),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2.0,
                    children: [
                      THText('I’m a tradie', style: THTextStyle.title),
                      THText('Get leads, set your rate, get paid.', style: THTextStyle.meta, tone: THTone.soft),
                    ],
                  ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          THButton(
            label: 'Continue',
            kind: THButtonKind.primary,
            onPressed: () {},
          ),
          ],
        ),
    );
  }
}
