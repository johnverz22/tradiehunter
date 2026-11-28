import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'th_tokens.dart';
import 'th_widgets.dart';

// Timeline fractions of the Lottie composition, not design tokens.
const double _kHoldStart = 0.72;
const double _kHoldEnd = 0.84;
const double _kHoldMid = 0.78;

/// Animated TradieHunter house-and-hammer loader (Lottie).
///
/// Loops while [isLoading] is true; when [isLoading] becomes false, finishes
/// the current cycle into the hold window ([_kHoldStart]..[_kHoldEnd]) and
/// stops on the assembled logo, firing [onSettled] once.
class ThTradieLoader extends StatefulWidget {
  const ThTradieLoader({
    super.key,
    required this.isLoading,
    this.onSettled,
    this.size = Sizes.tradieLoader,
    this.assetOverride,
  });

  final bool isLoading;
  final VoidCallback? onSettled;
  final double size;

  /// Optional asset path override (primarily for tests).
  final String? assetOverride;

  @override
  State<ThTradieLoader> createState() => _ThTradieLoaderState();
}

class _ThTradieLoaderState extends State<ThTradieLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _loaded = false;
  bool _settledFired = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)..addListener(_handleTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextReduce = MediaQuery.disableAnimationsOf(context);
    if (nextReduce != _reduceMotion) {
      _reduceMotion = nextReduce;
      if (_loaded) {
        if (_reduceMotion) {
          _controller.stop();
          _controller.value = _kHoldMid;
        } else if (widget.isLoading) {
          _settledFired = false;
          _controller.repeat();
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant ThTradieLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_loaded) return;
    if (widget.isLoading && !oldWidget.isLoading) {
      _settledFired = false;
      if (!_reduceMotion) {
        _controller.repeat();
      }
    } else if (!widget.isLoading && oldWidget.isLoading && _reduceMotion) {
      _controller.stop();
      _controller.value = _kHoldMid;
      _fireSettled();
    }
  }

  void _handleTick() {
    if (!widget.isLoading && _controller.isAnimating) {
      final v = _controller.value;
      if (v >= _kHoldStart && v <= _kHoldEnd) {
        _controller.stop();
        _fireSettled();
      }
    }
  }

  void _fireSettled() {
    if (_settledFired) return;
    _settledFired = true;
    widget.onSettled?.call();
  }

  void _onLoaded(LottieComposition composition) {
    _loaded = true;
    _controller.duration = composition.duration;
    if (_reduceMotion || !widget.isLoading) {
      _controller.value = _kHoldMid;
      if (!widget.isLoading) {
        _fireSettled();
      }
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset =
        widget.assetOverride ?? 'assets/lottie/tradiehunter_loader.json';

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: Lottie.asset(
          asset,
          controller: _controller,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          onLoaded: _onLoaded,
          errorBuilder: (_, _, _) => SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(child: ThBrandMark(size: widget.size * 0.4)),
          ),
        ),
      ),
    );
  }
}
