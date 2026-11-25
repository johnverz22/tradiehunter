// ThTabAppBar: the title row for top-level tab screens (Jobs, Messages,
// Profile). Jobs renders its "My jobs" h1 inside the page body; this gives
// Messages and Profile the identical treatment (same h1 style, same gutter,
// same top inset) while still living in the Scaffold's appBar slot, so their
// loading/error/empty states keep the title.
import 'package:flutter/material.dart';

import '../design/th_scope.dart';
import '../design/th_test_id.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class ThTabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ThTabAppBar({
    super.key,
    required this.title,
    this.actions = const <Widget>[],
  });

  final String title;

  /// Trailing icon buttons (e.g. Profile's settings).
  final List<Widget> actions;

  // h1 row + the same s1_5 top / s3 bottom rhythm as the Jobs body; a bit
  // taller when an icon button sets the row height.
  @override
  Size get preferredSize => Size.fromHeight(actions.isEmpty ? 48 : 64);

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return thTestIdWrap(
      Material(
        color: c.paper,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Sizes.gutter,
              Space.s1_5,
              Sizes.gutter,
              Space.s2_5,
            ),
            child: Row(
              crossAxisAlignment: actions.isEmpty
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              spacing: Space.s3,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: THText(title, style: THTextStyle.h1),
                    ),
                  ),
                ),
                ...actions,
              ],
            ),
          ),
        ),
      ),
      key,
    );
  }
}
