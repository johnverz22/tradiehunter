import 'package:flutter/material.dart';

import '../design/th_tokens.dart';

/// Shared frame for the v2 modal bottom sheets: surface, top radius, drag
/// handle and keyboard-aware bottom padding.
class ThSheetFrame extends StatelessWidget {
  const ThSheetFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Container(
      padding: EdgeInsets.fromLTRB(
        Space.s6,
        Space.s3,
        Space.s6,
        MediaQuery.of(context).viewInsets.bottom + Space.s7,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: Space.s8,
              height: Space.s1,
              margin: const EdgeInsets.only(bottom: Space.s5),
              decoration: BoxDecoration(
                color: c.line,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
