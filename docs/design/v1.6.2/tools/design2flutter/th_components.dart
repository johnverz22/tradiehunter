// th_components.dart — REFERENCE CONTRACT for the TH* widgets emitted by
// tools/design2flutter. Copy into mobile/lib/widgets/ (or map to existing
// Fixo* widgets where noted) and implement against design_tokens.dart.
// Every constructor below matches exactly what the transpiler emits.
// IGNORE lint on this file in CI until implemented — it is the contract.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Status band placeholder (mockup status bar is OS chrome).
class THStatusBand extends StatelessWidget {
  const THStatusBand({super.key, this.onDark = false});
  final bool onDark;
  @override
  Widget build(BuildContext context) => const SizedBox(height: 44);
}

/// Bottom home-indicator placeholder (OS chrome).
class THHomeIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox(height: 24);
}

/// Hero band: navy gradient in EVERY theme; children laid out in a column.
/// Text on it uses THHeroGlass constants (theme-invariant by spec).
class THHeroBand extends StatelessWidget {
  const THHeroBand({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: THHeroGlass.bandGradient),
        child: Column(children: children),
      );
}

/// Map header: gradient map placeholder with scrimmed app bar slot.
class THMapHeader extends StatelessWidget {
  const THMapHeader({super.key, required this.children, this.heightRatio});
  final List<Widget> children;
  final double? heightRatio;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: (heightRatio ?? .38) * MediaQuery.sizeOf(context).height,
        child: Stack(children: children),
      );
}

/// Job status strip under the app bar (navy in both themes).
class THStatusStrip extends StatelessWidget {
  const THStatusStrip({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        color: THHeroGlass.strip, child: Column(children: children));
}

/// Status pill: action/active/waiting/done/muted/problem — tints per
/// design_tokens.json rules (15% tints, dark overrides).
class THStatusPill extends StatelessWidget {
  const THStatusPill({super.key, required this.kind, required this.label, this.icon});
  final String kind; final String label; final IconData? icon;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Non-interactive credential label (26px) — NEVER a filter chip.
class THBadge extends StatelessWidget {
  const THBadge({super.key, required this.label, this.good = false, this.icon});
  final String label; final bool good; final IconData? icon;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Scrolling chip row: horizontal ListView, 32px right fade, snap.
class THFadeRow extends StatelessWidget {
  const THFadeRow({super.key, required this.children, this.fadeWidth});
  final List<Widget> children; final double? fadeWidth;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Step progress ("Step 2 of 4 · Booked").
class THStepProgress extends StatelessWidget {
  const THStepProgress({super.key, required this.step, required this.total, this.caption});
  final int step; final int total; final String? caption;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Respond-within countdown; urgent variant is the ONE permitted orange.
class THCountdown extends StatelessWidget {
  const THCountdown({super.key, this.urgent = false, this.progress, this.label});
  final bool urgent; final double? progress; final String? label;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Form field wrapper: label + input + helper/error.
class THField extends StatelessWidget {
  const THField({super.key, required this.children, this.label, this.error});
  final List<Widget> children; final String? label; final bool error;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Text input with state: default/focused/filled/error/disabled.
class THInput extends StatelessWidget {
  const THInput({super.key, required this.state, this.value, this.icon, this.placeholder});
  final String state; final String? value; final IconData? icon; final String? placeholder;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// OTP cell row.
class THOtpInput extends StatelessWidget {
  const THOtpInput({super.key, required this.length});
  final int length;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Segmented 48dp control.
class THSegmented extends StatelessWidget {
  const THSegmented({super.key, required this.options});
  final List<({String label, bool selected})> options;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Filter chip: 40dp visual, 48dp hit area, selected = brand fill.
class THFilterChip extends StatelessWidget {
  const THFilterChip({super.key, required this.label, this.selected = false, this.outlined = false});
  final String label; final bool selected; final bool outlined;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Urgency tag (urgency scale: low/normal/high).
class THUrgencyTag extends StatelessWidget {
  const THUrgencyTag({super.key, required this.level, required this.label});
  final String level; final String label;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Chat bubble (sent/recv tints).
class THChatBubble extends StatelessWidget {
  const THChatBubble({super.key, required this.sent, required this.text});
  final bool sent; final String text;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Message composer (attach + field + send).
class THComposer extends StatelessWidget {
  const THComposer({super.key, this.placeholder});
  final String? placeholder;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Thread row in the messages list.
class THMessageRow extends StatelessWidget {
  const THMessageRow({super.key, this.name, this.time, this.preview, this.unread = false});
  final String? name; final String? time; final String? preview; final bool unread;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Icon-only button: 48dp target, tooltip = label.
class THIconButton extends StatelessWidget {
  const THIconButton({super.key, required this.icon, this.label});
  final IconData icon; final String? label;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Bottom navigation (4/5 slot, optional rail) and FAB.
class THNavBar extends StatelessWidget {
  const THNavBar({super.key, required this.items, this.rail = false});
  final List<({String label, IconData icon, bool selected})> items; final bool rail;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Sticky bottom CTA area.
class THStickyCta extends StatelessWidget {
  const THStickyCta({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Grouped list (surface + dividers).
class THListGroup extends StatelessWidget {
  const THListGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// List row inside a group.
class THListRow extends StatelessWidget {
  const THListRow({super.key, required this.children, this.selected = false});
  final List<Widget> children; final bool selected;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Illustration/art slot. `semanticLabel: null` marks decorative art.
class THArt extends StatelessWidget {
  const THArt({super.key, required this.asset, this.semanticLabel});
  final String asset; final String? semanticLabel;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// The remaining small contracts (THDivider, THSheet, THToast, THBanner,
/// THSkeleton, THSwitch, THPhotoTile, THCategoryTile, THIconTile,
/// THServiceRow, THButtonRow) follow the same pattern — see the transpiler
/// output for the exact named parameters emitted.
