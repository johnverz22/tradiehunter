import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Standard filter pill for horizontal category/status selection rows.
///
/// Meets WCAG contrast in both light and dark modes:
/// - Selected (light): solid navy (`DesignTokens.brand900`), white label, white check icon.
/// - Selected (dark): raised brand tone (`DesignTokens.brand700`), light label, light check icon.
/// - Unselected: surface fill, hairline border token, ink label.
/// - Min height 48dp hit area (`Sizes.tapMin`).
/// - Label style from type scale (`DesignTokens.fontSizeSecondary`), no label wrapping.
class FixoFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final bool showCheckmark;
  final Key? pillKey;

  const FixoFilterPill({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
    this.showCheckmark = true,
    this.pillKey,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final th = Theme.of(context).extension<THColors>()!;

    final Color bgColor = selected
        ? (isDark ? DesignTokens.brand700 : DesignTokens.brand900)
        : th.surface;

    final Color fgColor = selected
        ? Colors.white
        : th.text;

    final Border border = selected
        ? Border.all(
            color: isDark ? DesignTokens.brand500 : DesignTokens.brand900,
            width: Sizes.borderWidthThin,
          )
        : Border.all(
            color: DesignTokens.paperLine(isDark),
            width: Sizes.borderWidthThin,
          );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: Sizes.filterPillMinH,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: pillKey,
            onTap: onSelected != null ? () => onSelected!(!selected) : null,
            borderRadius: BorderRadius.circular(Radii.pill),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: Sizes.filterPillH,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s3_5,
                  vertical: Space.s1_5,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: border,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (selected && showCheckmark) ...[
                      Icon(
                        Icons.check_rounded,
                        size: Sizes.iconRating,
                        color: fgColor,
                      ),
                      const SizedBox(width: Sizes.chipIconGap),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: DesignTokens.fontBody,
                          fontSize: DesignTokens.fontSizeSecondary,
                          fontWeight: selected ? FW.semibold : FW.medium,
                          color: fgColor,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
