# TradieHunter Loader (Lottie)

A looping loading animation for the TradieHunter app. A hammer strikes six times, and each strike snaps a floating piece of the house logo into place. The sixth strike completes the logo with a pulse, then the pieces drift apart and it repeats.

Use it while suggested tradies load. When results arrive, it can settle on the finished logo instead of cutting off mid-animation.

## Files

| File | Purpose |
| --- | --- |
| `tradiehunter_loader.json` | Universal loader. Recolor the house at runtime for light and dark themes. |
| `tradiehunter_loader_dark.json` | Optional pre-colored dark version (white house). Same timing and shapes. |

## Setup

```yaml
# pubspec.yaml
dependencies:
  lottie: ^3.1.0

flutter:
  assets:
    - assets/lottie/tradiehunter_loader.json
```

## Quick start

```dart
Lottie.asset(
  'assets/lottie/tradiehunter_loader.json',
  width: 220,
  repeat: true,
)
```

The canvas is square with empty margin around the logo, so pieces have room to float. Size the widget generously (200 to 260 logical pixels works well).

## Light and dark theme

The house outline is dark blue, which disappears on dark backgrounds. Its fill is named `HouseFill`, so one file can serve both themes:

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;

Lottie.asset(
  'assets/lottie/tradiehunter_loader.json',
  width: 220,
  delegates: LottieDelegates(
    values: [
      ValueDelegate.color(
        const ['**', 'HouseFill'],
        value: isDark ? Colors.white : const Color(0xFF1E3A8A),
      ),
    ],
  ),
)
```

If the recolor doesn't apply on your `lottie` version, switch between the two files instead:

```dart
Lottie.asset(isDark
    ? 'assets/lottie/tradiehunter_loader_dark.json'
    : 'assets/lottie/tradiehunter_loader.json')
```

## Loop until results arrive, then settle

A fixed loop can cut off mid-scatter when data arrives. This widget keeps looping while `isLoading` is true. When loading ends, it lets the animation play on until the finished logo is on screen, stops there, and calls `onSettled` so you can fade in the results.

It never seeks backwards, so there is no flicker.

```dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class TradieLoader extends StatefulWidget {
  const TradieLoader({
    super.key,
    required this.isLoading,
    this.onSettled,
    this.size = 220,
  });

  final bool isLoading;
  final VoidCallback? onSettled;
  final double size;

  @override
  State<TradieLoader> createState() => _TradieLoaderState();
}

class _TradieLoaderState extends State<TradieLoader>
    with SingleTickerProviderStateMixin {
  // Fraction of the 5.2 s timeline where the finished logo is on screen.
  static const _holdStart = 0.72;
  static const _holdEnd = 0.84;

  late final AnimationController _c = AnimationController(vsync: this)
    ..addListener(_onTick);

  void _onTick() {
    final inHold = _c.value >= _holdStart && _c.value <= _holdEnd;
    if (!widget.isLoading && _c.isAnimating && inHold) {
      _c.stop();
      widget.onSettled?.call();
    }
  }

  @override
  void didUpdateWidget(TradieLoader old) {
    super.didUpdateWidget(old);
    // A new search started: resume looping.
    if (widget.isLoading && !old.isLoading && !_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Lottie.asset(
      'assets/lottie/tradiehunter_loader.json',
      controller: _c,
      width: widget.size,
      onLoaded: (composition) {
        _c.duration = composition.duration;
        if (MediaQuery.of(context).disableAnimations) {
          // Respect reduced motion: show the finished logo, no looping.
          _c.value = (_holdStart + _holdEnd) / 2;
        } else {
          _c.repeat();
        }
      },
      delegates: LottieDelegates(
        values: [
          ValueDelegate.color(
            const ['**', 'HouseFill'],
            value: isDark ? Colors.white : const Color(0xFF1E3A8A),
          ),
        ],
      ),
    );
  }
}
```

Usage:

```dart
TradieLoader(
  isLoading: state.isSearching,
  onSettled: () => setState(() => _showResults = true),
)
```

## Timeline

Total length 5.2 s, looping.

| Time | What happens |
| --- | --- |
| 0.0 to 0.9 s | Pieces fade in, tilted and floating. Hammer winds up. |
| 0.9 s | Strike 1: left roof piece snaps in. |
| 1.4 s | Strike 2: right roof piece. |
| 1.9 s | Strike 3: lower-left piece. |
| 2.4 s | Strike 4: lower-right piece. |
| 2.9 s | Strike 5: orange accent. |
| 3.4 s | Strike 6: finale pulse. Logo is complete. |
| 3.7 to 4.4 s | Finished logo holds (0.72 to 0.84 of the timeline). |
| 4.4 to 5.2 s | Pieces drift apart and fade, hammer resets, loop restarts. |

## Technical details

| Property | Value |
| --- | --- |
| Canvas | 720 × 720, transparent background |
| Frame rate | 60 fps, 312 frames |
| File size | about 212 KB |
| Features used | Shape layers and keyframes only. No masks, expressions, effects or images. |

Colours:

| Element | Colour | Name in file |
| --- | --- | --- |
| House outline | `#1E3A8A` (white in the dark file) | `HouseFill` |
| Hammer | `#8FA8F2` | n/a |
| Orange accent | `#B45309` | `AccentFill` |

## Status

Checked frame by frame in lottie-web, in light and dark. Not yet run in the Flutter `lottie` package, so confirm on a device. In particular, check that the `HouseFill` recolor applies on your `lottie` version.

## Troubleshooting

- **Logo is invisible on a dark background:** the house is still dark blue. Apply the `HouseFill` color delegate or use the dark file.
- **Recolor has no effect:** use the two-file approach above.
- **Animation looks too small:** the canvas includes margin for the floating pieces. Increase `width`, or crop the margin.
- **Loader doesn't stop when loading ends:** make sure `isLoading` actually flips to `false` and that the same `TradieLoader` widget instance stays in the tree. Rebuilding it with a new key restarts the controller.