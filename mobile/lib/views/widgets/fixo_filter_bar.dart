import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'fixo_filter_pill.dart';

/// Single horizontally scrollable filter pill row with fading edge hints
/// and automatic scroll-into-view on selection.
class FixoFilterBar<T> extends StatefulWidget {
  final List<T> items;
  final T selectedItem;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onSelected;
  final Key? listKey;
  final Key Function(T)? itemKeyBuilder;

  const FixoFilterBar({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.labelBuilder,
    required this.onSelected,
    this.listKey,
    this.itemKeyBuilder,
  });

  @override
  State<FixoFilterBar<T>> createState() => _FixoFilterBarState<T>();
}

class _FixoFilterBarState<T> extends State<FixoFilterBar<T>> {
  late final ScrollController _scrollController;
  late List<GlobalKey> _itemKeys;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _itemKeys = List.generate(widget.items.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(FixoFilterBar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != _itemKeys.length) {
      _itemKeys = List.generate(widget.items.length, (_) => GlobalKey());
    }
    if (oldWidget.selectedItem != widget.selectedItem) {
      final index = widget.items.indexOf(widget.selectedItem);
      if (index >= 0) {
        _scrollToIndex(index);
      }
    }
  }

  void _scrollToIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _itemKeys.length) return;
      final ctx = _itemKeys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: FixoDurations.fast,
          alignment: 0.5,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.04, 0.96, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        key: widget.listKey,
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s4,
          vertical: Space.s2,
        ),
        child: Row(
          children: [
            for (int i = 0; i < widget.items.length; i++) ...[
              KeyedSubtree(
                key: _itemKeys[i],
                child: FixoFilterPill(
                  pillKey: widget.itemKeyBuilder?.call(widget.items[i]),
                  label: widget.labelBuilder(widget.items[i]),
                  selected: widget.selectedItem == widget.items[i],
                  showCheckmark: true,
                  onSelected: (_) {
                    widget.onSelected(widget.items[i]);
                    _scrollToIndex(i);
                  },
                ),
              ),
              if (i < widget.items.length - 1)
                const SizedBox(width: Space.s2),
            ],
          ],
        ),
      ),
    );
  }
}
