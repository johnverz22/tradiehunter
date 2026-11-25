// ThChoicePills: tappable pill row for v2 screens (migration plan 4.1 #4).
//
// The generated `THPills` in th_widgets.dart is display-only (no onTap, no
// selected semantics). That file stays a copy of the generated design source,
// so the interactive variant lives here in lib/ui/shared/ and reuses the same
// visual tokens. Each pill gets its own Key and a 44px tap target; state is
// exposed to screen readers through Semantics(button/selected/label).
import 'package:flutter/material.dart';

import '../design/th_test_id.dart';
import '../design/th_tokens.dart';

class ThChoicePillItem {
  const ThChoicePillItem({
    required this.label,
    this.key,
    this.selected = false,
    this.icon,
    this.onSelected,
  });

  final String label;
  final Key? key;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onSelected;
}

class ThChoicePills extends StatelessWidget {
  const ThChoicePills({super.key, required this.items, this.singleRow = false});

  final List<ThChoicePillItem> items;

  /// Lay every pill out on one row, sharing the width equally. Labels scale
  /// down rather than wrap, so a short fixed set (e.g. the post-job timing
  /// choices) never spills onto a second line.
  final bool singleRow;

  @override
  Widget build(BuildContext context) {
    if (singleRow) {
      return thTestIdWrap(
        Row(
          spacing: Space.s2,
          children: [
            for (final item in items)
              Expanded(child: _Pill(item: item, fill: true)),
          ],
        ),
        key,
      );
    }
    return thTestIdWrap(
      Wrap(
        spacing: Space.s2,
        runSpacing: Space.s2,
        children: [for (final item in items) _Pill(item: item)],
      ),
      key,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.item, this.fill = false});

  final ThChoicePillItem item;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final selected = item.selected;
    final radius = BorderRadius.circular(Radii.pill);
    final foreground = selected ? c.onBrand : c.text;

    return Semantics(
      button: true,
      selected: selected,
      identifier: thTestId(item.key),
      label: item.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? c.brand : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? c.brand : c.line),
        ),
        child: InkWell(
          key: item.key,
          onTap: item.onSelected,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.buttonSm),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: fill ? Space.s2 : Space.s3_5,
                vertical: Space.s2,
              ),
              child: fill
                  ? Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          style: THType.meta.copyWith(
                            fontWeight: FontWeight.w500,
                            color: foreground,
                          ),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: Space.s1_5,
                      children: [
                        if (item.icon != null)
                          Icon(
                            item.icon,
                            size: Sizes.iconSm,
                            color: foreground,
                          ),
                        Text(
                          item.label,
                          style: THType.meta.copyWith(
                            fontWeight: FontWeight.w500,
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
