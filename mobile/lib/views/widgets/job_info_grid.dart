import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class JobInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  const JobInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = DesignTokens.surfaceCard(dark);
    final border = dark
        ? DesignTokens.paperLineDark
        : DesignTokens.paperLineLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusTile),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: DesignTokens.foregroundBrand(dark)),
          const SizedBox(height: Space.s2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: Space.s1),
          Text(
            value,
            style: emphasized
                ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: DesignTokens.fontSizeAmount,
                    fontWeight: FW.bold,
                    color: DesignTokens.foreground(dark),
                  )
                : Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontSize: DesignTokens.fontSizeH3, fontWeight: FW.semibold),
          ),
        ],
      ),
    );
  }
}

class JobInfoGrid extends StatelessWidget {
  final List<JobInfoTile> tiles;

  const JobInfoGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 280 &&
              MediaQuery.textScalerOf(context).scale(16) <= 24
          ? 2
          : 1;
      return Column(
        children: [
          for (var i = 0; i < tiles.length; i += columns)
            Padding(
              padding: EdgeInsets.only(
                bottom: i + columns < tiles.length ? DesignTokens.cardGap : 0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < columns; j++) ...[
                      if (j > 0) const SizedBox(width: DesignTokens.cardGap),
                      Expanded(
                        child: i + j < tiles.length
                            ? tiles[i + j]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
