// GENERATED from ast/screens.mjs (id: notifications, route: /notifications). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../th_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const String route = '/notifications';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Notifications'),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THListRow(icon: Icons.attach_money_rounded, title: 'Approve final amount', subtitle: 'Aroha Plumbing finished · \$261.00 · 2m', unread: true),
          THListRow(icon: Icons.add_rounded, title: 'Extra cost request', subtitle: '\$48.50 materials · 1h', unread: true, divider: true),
          THListRow(icon: Icons.check_rounded, title: 'Aroha Plumbing accepted', subtitle: 'Leaking kitchen tap · Yesterday', divider: true),
          THListRow(icon: Icons.description_rounded, title: 'Quote received', subtitle: 'Bay Builders · \$18,400 · Yesterday', divider: true),
          THListRow(icon: Icons.verified_user_rounded, title: 'Licence verified', subtitle: 'Your profile is now live · 2d', divider: true),
          ],
        ),
    );
  }
}
