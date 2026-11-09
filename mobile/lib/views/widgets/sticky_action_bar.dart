import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class StickyActionBar extends StatelessWidget {
  final Widget child;

  const StickyActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: DesignTokens.shadowCard,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(Space.gutter, Space.s3, Space.gutter, Space.s4),
        child: child,
      ),
    ),
  );
}
