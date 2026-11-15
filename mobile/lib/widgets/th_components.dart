// th_components.dart — v1.6.2 design-system contract widgets (TH* family).
//
// Reference contract: docs/design/v1.6.2/tools/design2flutter/th_components.dart
// (signatures match exactly what the design2flutter AST transpiler emits).
// Mapping table: docs/design/v1.6.2/agent/AGENT_GUIDE.md §4.
//
// Rules honoured here:
// - Tokens only — every value comes from Space/Radii/Sizes/THType/THColors/
//   THPalette/THHeroGlass. The only theme branches are the documented
//   theme-invariant hero constants (THHeroGlass.strip) and avatar pairs.
// - F-102: pills riding a THStatusStrip render white-on-translucent (the
//   strip is navy in both themes) — implemented with a scope so the CSS
//   cascade (`.status-strip .pill`) maps 1:1.
// - F-110: every icon-only control carries a tooltip/semantic label.
// - The 12px text floor and the 48dp tap-target floor are respected.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/design_tokens.dart';

// ── OS-chrome placeholders ──────────────────────────────────────────────────

/// Status band placeholder (mockup status bar is OS chrome).
class THStatusBand extends StatelessWidget {
  const THStatusBand({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) => const SizedBox(height: 44);
}

/// Bottom home-indicator placeholder (OS chrome).
class THHomeIndicator extends StatelessWidget {
  const THHomeIndicator({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 24);
}

// ── Hero / header surfaces ──────────────────────────────────────────────────

/// Hero band: navy gradient in EVERY theme; children laid out in a column.
/// Text on it uses THHeroGlass constants (theme-invariant by spec).
class THHeroBand extends StatelessWidget {
  const THHeroBand({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: THHeroGlass.bandGradient),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
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
    child: DecoratedBox(
      decoration: const BoxDecoration(gradient: THHeroGlass.bandGradient),
      child: Stack(children: children),
    ),
  );
}

/// Scope marking "inside the navy status strip" so [THStatusPill] can apply
/// the `.status-strip .pill` cascade (white ink on translucent white) — F-102.
class _StripScope extends InheritedWidget {
  const _StripScope({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StripScope>() != null;

  @override
  bool updateShouldNotify(_StripScope oldWidget) => false;
}

/// Job status strip under the app bar (navy in both themes).
class THStatusStrip extends StatelessWidget {
  const THStatusStrip({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _StripScope(
      child: Container(
        color: THHeroGlass.strip(isDark),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: Space.s3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

// ── Pills / badges / chips ──────────────────────────────────────────────────

/// Status pill: action/active/waiting/done/muted/problem — tints per
/// design_tokens.json rules (12-15% tints, dark overrides). Inside a
/// [THStatusStrip] the F-102 cascade applies: translucent white fill, fixed
/// white ink (strip is navy in both themes).
class THStatusPill extends StatelessWidget {
  const THStatusPill({
    super.key,
    required this.kind,
    required this.label,
    this.icon,
  });

  final String kind;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final onStrip = _StripScope.of(context);

    // Fill / ink per kind (light+dark resolve through THColors).
    final (fill, ink) = switch (kind) {
      'action' => (
        th.accent.withValues(alpha: Alpha.tintAccent),
        th.accentText,
      ),
      'active' => (th.tintBrand, onStrip ? THHeroGlass.onHero : th.textBrand),
      'waiting' => (th.tintBrand, onStrip ? THHeroGlass.onHero : th.textBrand),
      'done' => (th.success.withValues(alpha: Alpha.tintStrong), th.success),
      'problem' => (th.danger.withValues(alpha: Alpha.tintLight), th.danger),
      _ => (th.track, onStrip ? THHeroGlass.onHero : th.textSoft), // muted
    };

    return Container(
      constraints: const BoxConstraints(minHeight: Sizes.statusBadgeH),
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s3,
        vertical: Space.s1_5,
      ),
      decoration: BoxDecoration(
        color: onStrip ? Colors.white.withValues(alpha: Alpha.tintDark) : fill,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: Sizes.iconChip, color: ink),
            const SizedBox(width: Sizes.chipIconGap),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: TypeTokens.fontBody,
              fontSize: DesignTokens.fontSizeStatus,
              fontWeight: FW.semibold,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Non-interactive credential label (28dp pill) — NEVER a filter chip.
class THBadge extends StatelessWidget {
  const THBadge({super.key, required this.label, this.good = false, this.icon});

  final String label;
  final bool good;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final fill = good
        ? th.success.withValues(alpha: Alpha.tintStrong)
        : th.track;
    final ink = good ? th.success : th.textSoft;
    return Container(
      constraints: const BoxConstraints(minHeight: Sizes.statusChip),
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s2_5,
        vertical: Space.s1,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: Sizes.iconChip, color: ink),
            const SizedBox(width: Sizes.chipIconGap),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: TypeTokens.fontBody,
              fontSize: DesignTokens.fontSizeStatus,
              fontWeight: FW.medium,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrolling chip row: horizontal ListView, 32px right fade, snap.
/// (audit F-04 lesson: never a clipped Row).
class THFadeRow extends StatelessWidget {
  const THFadeRow({super.key, required this.children, this.fadeWidth});

  final List<Widget> children;
  final double? fadeWidth;

  @override
  Widget build(BuildContext context) {
    final width = fadeWidth ?? 2 * Space.gutter - Space.s4; // 32
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0, (1 - width / bounds.width).clamp(0.0, 1.0), 1],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ListView(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        children: children
            .map(
              (c) => Padding(
                padding: const EdgeInsets.only(right: Space.s2),
                child: c,
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Step progress ("Step 2 of 4 · Booked") — segmented bar + caption.
class THStepProgress extends StatelessWidget {
  const THStepProgress({
    super.key,
    required this.step,
    required this.total,
    this.caption,
  });

  final int step;
  final int total;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(total, (i) {
            final on = i < step;
            return Expanded(
              child: Container(
                height: Sizes.progressSegH,
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : Space.s1),
                decoration: BoxDecoration(
                  color: on ? th.brand : th.track,
                  borderRadius: BorderRadius.circular(Radii.micro),
                ),
              ),
            );
          }),
        ),
        if (caption != null) ...[
          const SizedBox(height: Space.s2),
          Text(caption!, style: THType.caption.copyWith(color: th.textSoft)),
        ],
      ],
    );
  }
}

/// Respond-within countdown; urgent variant is the ONE permitted orange.
class THCountdown extends StatelessWidget {
  const THCountdown({
    super.key,
    this.urgent = false,
    this.progress,
    this.label,
  });

  final bool urgent;
  final double? progress;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final ink = urgent ? th.accentText : th.textSoft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Text(label!, style: THType.secondaryW600.copyWith(color: ink)),
        if (progress != null) ...[
          const SizedBox(height: Space.s1_5),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: progress!.clamp(0.0, 1.0),
              minHeight: Sizes.expiryProgressH,
              backgroundColor: th.track,
              valueColor: AlwaysStoppedAnimation(urgent ? th.accent : th.brand),
            ),
          ),
        ],
      ],
    );
  }
}

/// Urgency tag (urgency scale: low/normal/high). HIGH is an amber urgency
/// element — screens may carry at most ONE alongside the primary CTA.
class THUrgencyTag extends StatelessWidget {
  const THUrgencyTag({super.key, required this.level, required this.label});

  final String level;
  final String label;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final isHigh = level == 'high';
    final fill = isHigh
        ? th.accent.withValues(alpha: Alpha.tintAccent)
        : th.track;
    final ink = isHigh ? th.accentText : th.textSoft;
    return Container(
      constraints: const BoxConstraints(minHeight: Sizes.statusChip),
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s2_5,
        vertical: Space.s1,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: TypeTokens.fontBody,
          fontSize: DesignTokens.fontSizeStatus,
          fontWeight: FW.bold,
          letterSpacing: Tracking.wider,
          color: ink,
        ),
      ),
    );
  }
}

// ── Form controls ───────────────────────────────────────────────────────────

/// Form field wrapper: label + input(s) + error caption.
class THField extends StatelessWidget {
  const THField({
    super.key,
    this.children,
    this.child,
    this.label,
    this.error = false,
  });

  final List<Widget>? children;
  final Widget? child;
  final String? label;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: THType.caption.copyWith(color: th.textSoft)),
          const SizedBox(height: Space.s2),
        ],
        ?child,
        ...?children,
        if (error) ...[
          const SizedBox(height: Space.s1_5),
          Text(
            'Check this field and try again',
            style: THType.caption.copyWith(color: th.danger),
          ),
        ],
      ],
    );
  }
}

/// Text input with state: default/focused/filled/error/disabled (56dp).
/// Scaffold-only: state is a parameter, not wired to a controller — swap for
/// TextFormField when wiring real forms.
class THInput extends StatelessWidget {
  const THInput({
    super.key,
    required this.state,
    this.value,
    this.icon,
    this.placeholder,
  });

  final String state;
  final String? value;
  final IconData? icon;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color fill;
    final Color border;
    final double borderWidth;
    final Color ink;
    switch (state) {
      case 'focused':
        fill = th.surface;
        border = th.brand;
        borderWidth = Sizes.borderWidthThick;
        ink = th.text;
      case 'error':
        fill = th.surface;
        border = th.danger;
        borderWidth = Sizes.borderWidthThick;
        ink = th.textSoft;
      case 'disabled':
        fill = DesignTokens.surfaceDisabled(isDark);
        border = th.line;
        borderWidth = Sizes.borderWidthThin;
        ink = DesignTokens.foregroundDisabled(isDark);
      case 'filled':
        fill = th.surface;
        border = th.line;
        borderWidth = Sizes.borderWidthThin;
        ink = th.text;
      default: // 'default'
        fill = th.surface;
        border = DesignTokens.borderControl(isDark);
        borderWidth = Sizes.borderWidthThin;
        ink = th.textSoft;
    }

    return Container(
      height: Sizes.input,
      padding: const EdgeInsets.symmetric(horizontal: Space.s4),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: border, width: borderWidth),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: Sizes.iconMd, color: ink),
            const SizedBox(width: Space.s2_5),
          ],
          Expanded(
            child: Text(
              value ?? placeholder ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: THType.body.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// OTP cell row — display scaffold; the live screen uses OtpCodeField.
class THOtpInput extends StatelessWidget {
  const THOtpInput({super.key, required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Row(
      children: List.generate(
        length,
        (i) => Expanded(
          child: Container(
            height: Sizes.avatarMd,
            margin: EdgeInsets.only(right: i == length - 1 ? 0 : Space.s2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: th.surface,
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(
                color: DesignTokens.borderControl(
                  Theme.of(context).brightness == Brightness.dark,
                ),
                width: Sizes.borderWidthThin,
              ),
            ),
            child: Text('•', style: THType.price.copyWith(color: th.text)),
          ),
        ),
      ),
    );
  }
}

/// Segmented 48dp control.
class THSegmented extends StatelessWidget {
  const THSegmented({super.key, required this.options});

  final List<({String label, bool selected})> options;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Container(
      height: Sizes.tapMin,
      padding: const EdgeInsets.all(Space.s1),
      decoration: BoxDecoration(
        color: th.track,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        children: [
          for (final (i, o) in options.indexed) ...[
            if (i > 0) const SizedBox(width: Space.s1),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: o.selected ? th.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.small),
                ),
                child: Text(
                  o.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: THType.secondaryW600.copyWith(
                    color: o.selected ? th.onBrand : th.textSoft,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Filter chip: 40dp visual, 48dp hit area, selected = brand fill.
class THFilterChip extends StatelessWidget {
  const THFilterChip({
    super.key,
    required this.label,
    this.selected = false,
    this.outlined = false,
  });

  final String label;
  final bool selected;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      selected: selected,
      child: Container(
        height: Sizes.tapMin, // 48dp hit target; visual fill inset below
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Space.s4),
        decoration: BoxDecoration(
          color: selected ? th.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: outlined && !selected
              ? Border.all(
                  color: DesignTokens.borderControl(isDark),
                  width: Sizes.borderWidthThin,
                )
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: THType.secondaryW600.copyWith(
            color: selected ? th.onBrand : th.text,
          ),
        ),
      ),
    );
  }
}

/// Theme-styled switch — display scaffold; wire real callbacks at call site.
class THSwitch extends StatelessWidget {
  const THSwitch({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Switch(
      value: value,
      onChanged: (v) {
        /* TODO: wire action */
      },
      activeThumbColor: th.brand,
      activeTrackColor: th.tintBrand,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Icon-only button: 48dp target, tooltip = label (F-110).
class THIconButton extends StatelessWidget {
  const THIconButton({super.key, required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return IconButton(
      tooltip: label ?? 'Action',
      onPressed: () {
        /* TODO: wire action */
      },
      icon: Icon(icon, size: Sizes.iconMd, color: th.text),
    );
  }
}

/// Screen title inside hero bands and app bars.
/// Ink resolves from the ambient DefaultTextStyle so the same widget reads
/// white on navy heroes and brand-900 on paper (theme-correct by default).
class THAppBarTitle extends StatelessWidget {
  const THAppBarTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: THType.section);
}

/// Illustration/art slot. `semanticLabel: null` marks decorative art
/// (F-111: decorative art stays out of the a11y tree).
class THArt extends StatelessWidget {
  const THArt({super.key, required this.asset, this.semanticLabel});

  final String asset;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      semanticsLabel: semanticLabel,
      // Scaffolds may reference art sets not bundled for every build;
      // a blank slot beats a broken frame.
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

// ── Lists / cards ───────────────────────────────────────────────────────────

/// Grouped list (surface + dividers between rows).
class THListGroup extends StatelessWidget {
  const THListGroup({super.key, this.children, this.child});

  final List<Widget>? children;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final items = child != null ? [child!] : (children ?? const <Widget>[]);
    return Container(
      decoration: BoxDecoration(
        color: th.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: th.line, width: Sizes.borderWidthHair),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in items.indexed) ...[
            if (i > 0)
              Divider(
                height: Sizes.borderWidthThin,
                thickness: Sizes.borderWidthThin,
                color: th.line,
              ),
            row,
          ],
        ],
      ),
    );
  }
}

/// List row inside a [THListGroup]. Selected = brand tint (selection is
/// NEVER amber — design rule 4).
class THListRow extends StatelessWidget {
  const THListRow({
    super.key,
    this.children,
    this.child,
    this.selected = false,
  });

  final List<Widget>? children;
  final Widget? child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final content = child ?? Column(children: children ?? const <Widget>[]);
    return Container(
      color: selected ? th.tintBrand : Colors.transparent,
      padding: const EdgeInsets.all(Space.s4),
      child: content,
    );
  }
}

/// Service row (tradie service catalog) with optional rate suffix.
class THServiceRow extends StatelessWidget {
  const THServiceRow({super.key, required this.label, this.rate});

  final String label;
  final String? rate;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: THType.body.copyWith(color: th.text)),
          ),
          if (rate != null)
            Text(rate!, style: THType.secondary.copyWith(color: th.textSoft)),
        ],
      ),
    );
  }
}

/// Category tile ("Electrical · 38 active tradies").
class THCategoryTile extends StatelessWidget {
  const THCategoryTile({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(
        color: th.surface,
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: th.line, width: Sizes.borderWidthHair),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: THType.cardTitle.copyWith(color: th.text),
            ),
          ),
          Icon(Icons.chevron_right, size: Sizes.iconMd, color: th.textSoft),
        ],
      ),
    );
  }
}

/// Square icon tile (add-service / misc actions).
class THIconTile extends StatelessWidget {
  const THIconTile({super.key, this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Container(
      width: Sizes.avatarXl,
      height: Sizes.avatarXl,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: th.tintBrand,
        borderRadius: BorderRadius.circular(Radii.tile),
      ),
      child: Icon(icon ?? Icons.add, size: Sizes.iconLg, color: th.textBrand),
    );
  }
}

/// Photo tile placeholder (job photo gallery).
class THPhotoTile extends StatelessWidget {
  const THPhotoTile({super.key});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: th.track,
          borderRadius: BorderRadius.circular(Radii.tile),
        ),
        child: Icon(
          Icons.image_outlined,
          size: Sizes.iconLg,
          color: th.textSoft,
        ),
      ),
    );
  }
}

/// Skeleton loading block.
class THSkeleton extends StatelessWidget {
  const THSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Container(
      height: Sizes.input,
      decoration: BoxDecoration(
        color: th.track,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
    );
  }
}

/// Divider hairline.
class THDivider extends StatelessWidget {
  const THDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Container(height: Sizes.borderWidthThin, color: th.line);
  }
}

// ── Feedback surfaces ───────────────────────────────────────────────────────

/// Toast pill (component sheet cmp-toast).
class THToast extends StatelessWidget {
  const THToast({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: Sizes.noticeMinH),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s4,
          vertical: Space.s2,
        ),
        decoration: BoxDecoration(
          color: th.text,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          message,
          style: THType.secondaryW600.copyWith(color: th.paper),
        ),
      ),
    );
  }
}

/// Inline banner (cmp-banner): tone = info | error.
class THBanner extends StatelessWidget {
  const THBanner({super.key, required this.tone, required this.children});

  final String tone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final isError = tone == 'error';
    final fill = isError
        ? th.danger.withValues(alpha: Alpha.tintLight)
        : th.tintBrand;
    final ink = isError ? th.danger : th.textBrand;
    return Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: Sizes.iconMd,
            color: ink,
          ),
          const SizedBox(width: Space.s2_5),
          Expanded(
            child: DefaultTextStyle.merge(
              style: THType.secondary.copyWith(color: ink),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Button row — children share the row width equally.
class THButtonRow extends StatelessWidget {
  const THButtonRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, b) in children.indexed) ...[
        if (i > 0) const SizedBox(width: Space.s3),
        Expanded(child: b),
      ],
    ],
  );
}

// ── Chat ────────────────────────────────────────────────────────────────────

/// Chat bubble: sent = navy fill + white ink, recv = surface + border.
class THChatBubble extends StatelessWidget {
  const THChatBubble({super.key, required this.sent, required this.text});

  final bool sent;
  final String text;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Align(
      alignment: sent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: Space.s1),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s4,
          vertical: Space.s2_5,
        ),
        decoration: BoxDecoration(
          color: sent ? th.brand : th.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: sent
              ? null
              : Border.all(color: th.line, width: Sizes.borderWidthHair),
        ),
        child: Text(
          text,
          style: THType.body.copyWith(color: sent ? th.onBrand : th.text),
        ),
      ),
    );
  }
}

/// Message composer (attach + field + send). Display scaffold — the live
/// chat screen owns controllers and the SignalR send path.
class THComposer extends StatelessWidget {
  const THComposer({super.key, this.placeholder});

  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(
        color: th.surface,
        border: Border(
          top: BorderSide(color: th.line, width: Sizes.borderWidthThin),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Attach photo',
            onPressed: () {
              /* TODO: wire action */
            },
            icon: Icon(
              Icons.add_photo_alternate_outlined,
              size: Sizes.iconMd,
              color: th.textSoft,
            ),
          ),
          Expanded(
            child: Container(
              height: Sizes.buttonTonalSm,
              padding: const EdgeInsets.symmetric(horizontal: Space.s3),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: th.track,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Text(
                placeholder ?? 'Write a message…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: THType.secondary.copyWith(color: th.textSoft),
              ),
            ),
          ),
          const SizedBox(width: Space.s2),
          IconButton(
            tooltip: 'Send message',
            onPressed: () {
              /* TODO: wire action */
            },
            icon: Icon(Icons.send, size: Sizes.iconMd, color: th.accentText),
          ),
        ],
      ),
    );
  }
}

/// Thread row in the messages list.
class THMessageRow extends StatelessWidget {
  const THMessageRow({
    super.key,
    this.name,
    this.time,
    this.preview,
    this.unread = false,
  });

  final String? name;
  final String? time;
  final String? preview;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final initials = (name ?? '?')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
    return Container(
      constraints: const BoxConstraints(minHeight: Sizes.inboxTileMin),
      padding: const EdgeInsets.symmetric(
        vertical: Space.s2_5,
        horizontal: Space.gutter,
      ),
      child: Row(
        children: [
          Container(
            width: Sizes.inboxAvatarSm,
            height: Sizes.inboxAvatarSm,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: th.avTradie,
            ),
            child: Text(
              initials,
              style: THType.secondaryW600.copyWith(color: th.onAvTradie),
            ),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name ?? 'Conversation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: THType.cardTitle.copyWith(color: th.text),
                      ),
                    ),
                    if (time != null)
                      Text(
                        time!,
                        style: THType.caption.copyWith(color: th.textSoft),
                      ),
                  ],
                ),
                const SizedBox(height: Space.s0_5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        preview ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: THType.secondary.copyWith(
                          color: unread ? th.text : th.textSoft,
                          fontWeight: unread ? FW.semibold : FW.regular,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: Sizes.dot,
                        height: Sizes.dot,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: th.brand,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Navigation ──────────────────────────────────────────────────────────────

/// Bottom navigation (4/5 slot) or vertical rail for tablet layouts.
class THNavBar extends StatelessWidget {
  const THNavBar({super.key, required this.items, this.rail = false});

  final List<({String label, IconData icon, bool selected})> items;
  final bool rail;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color ink(bool sel) =>
        sel ? th.textBrand : (isDark ? THPalette.darkInkSoft : th.textSoft);

    if (rail) {
      return Container(
        width: Sizes.nav,
        decoration: BoxDecoration(
          color: th.surface,
          border: Border(
            right: BorderSide(color: th.line, width: Sizes.borderWidthThin),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              for (final item in items)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: Sizes.iconMd,
                        color: ink(item.selected),
                      ),
                      const SizedBox(height: Space.s1),
                      Text(
                        item.label,
                        style: THType.caption.copyWith(
                          color: ink(item.selected),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: th.surface,
        border: Border(
          top: BorderSide(color: th.line, width: Sizes.borderWidthThin),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: Sizes.nav - 24,
          child: Row(
            children: [
              for (final item in items)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: Sizes.iconMd,
                        color: ink(item.selected),
                      ),
                      const SizedBox(height: Space.s0_5),
                      Text(
                        item.label,
                        style: THType.caption.copyWith(
                          color: ink(item.selected),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sticky bottom CTA area — surface card pinned above the safe area.
class THStickyCta extends StatelessWidget {
  const THStickyCta({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.s3,
        Space.gutter,
        Space.s3,
      ),
      decoration: BoxDecoration(
        color: th.surface,
        border: Border(
          top: BorderSide(color: th.line, width: Sizes.borderWidthThin),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}
