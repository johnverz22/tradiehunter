# Dart recipes (uncompiled - verify token names and run `flutter analyze`)

## Status/trust badge that wraps (replaces a Row of chips)
```dart
class FixoBadge extends StatelessWidget {
  const FixoBadge({super.key, required this.label, this.icon, required this.color});
  final String label; final IconData? icon; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    height: Sizes.statusChip, // 26 - confirm which token class holds statusChip
    padding: const EdgeInsets.symmetric(horizontal: Space.s2_5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: Alpha.tintStandard),
      borderRadius: BorderRadius.circular(Radii.pill)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: Sizes.iconXs, color: color), const SizedBox(width: Space.s1)],
      Text(label, maxLines: 1, softWrap: false, style: TextStyle(
        fontSize: DesignTokens.fontSizeCaption, fontWeight: FW.semibold, color: color)),
    ]));
}
// usage: Wrap(spacing: Space.s2, runSpacing: Space.s2, children: [...FixoBadge])
```

## Scrolling chip row with fade (`.faderow`)
```dart
ShaderMask(
  shaderCallback: (r) => const LinearGradient(
    colors: [Colors.black, Colors.black, Colors.transparent],
    stops: [0, 0.9, 1]).createShader(r),   // derive stop from 32dp / r.width
  blendMode: BlendMode.dstIn,
  child: SizedBox(height: Sizes.tapMin, child: ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
    itemCount: items.length,
    separatorBuilder: (_, __) => const SizedBox(width: Space.s2),
    itemBuilder: (_, i) => items[i])),
)
```

## App bar back
Use `FixoAppBar`; change `preferredSize` to `Sizes.appBar`, glyph to `Sizes.iconLg`, and for routes opened with `context.go` pass a fallback:
```dart
onPressed: () => context.canPop() ? context.pop() : context.go(fallbackLocation)
```
On hero/map headers use a 44dp circular scrim (white ~78%) and white glyph on navy.

## Row text that must not truncate
`Row(children:[Expanded(child: Text.rich(...))])` or `Wrap`.
