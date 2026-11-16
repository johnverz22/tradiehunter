// GENERATED from ast/screens.mjs (id: profile, route: /profile). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const String route = '/profile';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      dock: THDock(role: THDockRole.homeowner, active: THDockTab.profile),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s1_5,
            children: [
              THAvatar('MR', size: THAvatarSize.lg),
              THText('Mere Rangi', style: THTextStyle.h2),
              THText('mere@example.co.nz', style: THTextStyle.meta, tone: THTone.soft),
            ],
          ),
          const SizedBox(height: 8.0),
          THCard(
            padding: Space.s1,
            children: [
              THListRow(icon: Icons.person_rounded, title: 'Personal details', flat: true),
              THListRow(icon: Icons.credit_card_rounded, title: 'Payments and receipts', flat: true, divider: true),
              THListRow(icon: Icons.notifications_rounded, title: 'Notifications', flat: true, divider: true),
            ],
          ),
          THCard(
            padding: Space.s1,
            children: [
              Padding(
                padding: EdgeInsets.all(Space.s3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s3,
                  children: [
                    THTile(Icons.dark_mode_rounded),
                    Expanded(
                      child: THText('Dark mode', style: THTextStyle.body),
                    ),
                    THSwitch(on: true),
                  ],
                ),
              ),
              THListRow(icon: Icons.help_outline_rounded, title: 'Help and support', flat: true),
            ],
          ),
          THButton(
            label: 'Sign out',
            kind: THButtonKind.ghost,
            onPressed: () {},
          ),
          ],
        ),
    );
  }
}
