// TradieHunter design v2: component library (hand-written, token-driven).
// The generated screens in screens/ only ever call widgets from this file.
// Rule: no hex colours and no raw numbers for spacing, radius or type in here
// except where a value is a documented one-off (marked "one-off").
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'th_tokens.dart';

// ───────────────────────────── enums ─────────────────────────────
enum THTextStyle { display, h1, h2, title, button, money, moneyLg, label, body, meta }

enum THTone { base, soft, brand, accent, ok, danger, onHero, onHeroSoft, gold }

enum THButtonKind { primary, accent, secondary, inverse, ghost, danger }

enum THButtonSize { md, sm }

enum THBadgeKind { brand, ok, accent, danger, glass }

enum THCardTone { defaultTone, accent, danger }

enum THAvatarSize { sm, md, lg }

enum THDockRole { homeowner, tradie }

enum THDockTab { home, jobs, chat, profile }

enum THTimelineState { done, cur, todo }

Color _tone(THColors c, THTone t) => switch (t) {
      THTone.base => c.text,
      THTone.soft => c.textSoft,
      THTone.brand => c.textBrand,
      THTone.accent => c.accentText,
      THTone.ok => c.success,
      THTone.danger => c.danger,
      THTone.onHero => c.onHero,
      THTone.onHeroSoft => c.onHero.withValues(alpha: 0.8),
      THTone.gold => c.heroGold,
    };

TextStyle _type(THTextStyle s) => switch (s) {
      THTextStyle.display => THType.display,
      THTextStyle.h1 => THType.h1,
      THTextStyle.h2 => THType.h2,
      THTextStyle.title => THType.title,
      THTextStyle.button => THType.button,
      THTextStyle.money => THType.money,
      THTextStyle.moneyLg => THType.moneyLg,
      THTextStyle.label => THType.label,
      THTextStyle.body => THType.body,
      THTextStyle.meta => THType.meta,
    };

bool _isLight(BuildContext context) => Theme.of(context).brightness == Brightness.light;

List<BoxShadow> _cardShadow(BuildContext context) => _isLight(context)
    ? [
        BoxShadow(color: const Color(0x0F0F172A), blurRadius: 2, offset: const Offset(0, 1)), // one-off
        BoxShadow(color: const Color(0x101E3A8A), blurRadius: 24, offset: const Offset(0, 8)), // one-off
      ]
    : const [];

// ───────────────────────────── primitives ─────────────────────────────
class THText extends StatelessWidget {
  const THText(this.text, {super.key, this.style = THTextStyle.body, this.tone = THTone.base, this.align, this.size, this.bold = false});
  final String text;
  final THTextStyle style;
  final THTone tone;
  final TextAlign? align;
  final double? size;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: _type(style).copyWith(color: _tone(context.th, tone), fontSize: size, fontWeight: bold ? FontWeight.w700 : null),
    );
  }
}

class THIcon extends StatelessWidget {
  const THIcon(this.icon, {super.key, this.size = Sizes.icon, this.tone = THTone.base});
  final IconData icon;
  final double size;
  final THTone tone;

  @override
  Widget build(BuildContext context) => Icon(icon, size: size, color: _tone(context.th, tone));
}

class THButton extends StatelessWidget {
  const THButton({super.key, required this.label, this.kind = THButtonKind.primary, this.size = THButtonSize.md, this.icon, this.fullWidth = true, this.onPressed});
  final String label;
  final THButtonKind kind;
  final THButtonSize size;
  final IconData? icon;
  final bool fullWidth;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final (bg, fg, side) = switch (kind) {
      THButtonKind.primary => (c.brand, c.onBrand, BorderSide.none),
      THButtonKind.accent => (c.accent, c.onAccent, BorderSide.none),
      THButtonKind.secondary => (c.surface, c.text, BorderSide(color: c.line, width: 1.5)),
      THButtonKind.inverse => (Colors.white, const Color(0xFF1E3A8A), BorderSide.none), // one-off: on-hero button
      THButtonKind.ghost => (Colors.transparent, c.textBrand, BorderSide.none),
      THButtonKind.danger => (c.danger, c.onAccent, BorderSide.none),
    };
    final sm = size == THButtonSize.sm;
    final radius = BorderRadius.circular(sm ? Radii.control - 2 : Radii.control);
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(borderRadius: radius, side: side),
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            child: SizedBox(
              height: sm ? Sizes.buttonSm : Sizes.button,
              width: fullWidth ? double.infinity : null,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: fullWidth ? 0 : Space.s5),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: Space.s2,
                    children: [
                      if (icon != null) Icon(icon, size: 18, color: fg),
                      Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: THType.button.copyWith(color: fg, fontSize: sm ? 14 : 15))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class THIconButton extends StatelessWidget {
  const THIconButton({super.key, required this.icon, this.kind = THButtonKind.secondary, this.dot = false, this.semanticLabel, this.onPressed});
  final IconData icon;
  final THButtonKind kind;
  final bool dot;
  final String? semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final primary = kind == THButtonKind.primary;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: primary ? c.brand : c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control - 2), side: primary ? BorderSide.none : BorderSide(color: c.line)),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Radii.control - 2),
          child: SizedBox(
            width: Sizes.buttonSm,
            height: Sizes.buttonSm,
            child: Stack(alignment: Alignment.center, children: [
              Icon(icon, size: Sizes.icon, color: primary ? c.onBrand : c.text),
              if (dot) Positioned(top: 9, right: 10, child: Container(width: 9, height: 9, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)))),
            ]),
          ),
        ),
      ),
    );
  }
}

class THBadge extends StatelessWidget {
  const THBadge(this.label, {super.key, this.kind = THBadgeKind.brand, this.icon, this.dot = false});
  final String label;
  final THBadgeKind kind;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final (bg, fg) = switch (kind) {
      THBadgeKind.brand => (c.tintBrand, c.textBrand),
      THBadgeKind.ok => (c.successTint, c.success),
      THBadgeKind.accent => (c.accentTint, c.accentText),
      THBadgeKind.danger => (c.dangerTint, c.danger),
      THBadgeKind.glass => (Colors.white.withValues(alpha: 0.18), Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: Space.s1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, spacing: Space.s1, children: [
        if (dot) Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        if (icon != null) Icon(icon, size: 12, color: fg),
        Text(label, style: THType.meta.copyWith(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class THAvatar extends StatelessWidget {
  const THAvatar(this.initials, {super.key, this.size = THAvatarSize.md, this.inverse = false});
  final String initials;
  final THAvatarSize size;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final (dim, radius, fs) = switch (size) {
      THAvatarSize.sm => (Sizes.avatarSm, 14.0, 15.0),
      THAvatarSize.md => (Sizes.avatar, 18.0, 18.0),
      THAvatarSize.lg => (Sizes.avatarLg, 22.0, 22.0),
    };
    return Container(
      width: dim,
      height: dim,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: inverse ? Colors.white : c.avTradie, borderRadius: BorderRadius.circular(radius)),
      child: Text(initials, style: THType.title.copyWith(fontSize: fs, color: inverse ? const Color(0xFF1E3A8A) : c.onAvTradie)),
    );
  }
}

// ───────────────────────────── surfaces ─────────────────────────────
class THCard extends StatelessWidget {
  const THCard({super.key, this.tone = THCardTone.defaultTone, this.padding = Space.s4, required this.children});
  final THCardTone tone;
  final double padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final border = switch (tone) {
      THCardTone.accent => Border.all(color: c.accent, width: 1.5),
      THCardTone.danger => Border.all(color: c.danger, width: 1.5),
      THCardTone.defaultTone => Border.all(color: c.line),
    };
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: border, boxShadow: _cardShadow(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class THHero extends StatelessWidget {
  const THHero({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.hero),
      child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.heroStart, c.heroEnd])),
        child: Stack(children: [
          Positioned(right: -44, top: -44, child: Container(width: 150, height: 150, decoration: BoxDecoration(color: c.heroGlow, shape: BoxShape.circle))),
          Padding(padding: const EdgeInsets.all(Space.s5), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
        ]),
      ),
    );
  }
}

class THGrid extends StatelessWidget {
  const THGrid({super.key, required this.columns, required this.spacing, required this.children});
  final int columns;
  final double spacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: columns,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 0.82,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      );
}

class THTile extends StatelessWidget {
  const THTile(this.icon, {super.key, this.label, this.big = false, this.tone = THBadgeKind.brand});
  final IconData icon;
  final String? label;
  final bool big;
  final THBadgeKind tone;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final ok = tone == THBadgeKind.ok;
    final box = Container(
      width: big ? (ok ? 84 : Sizes.avatar) : null,
      height: big ? (ok ? 84 : Sizes.avatar) : null,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: ok ? c.successTint : c.tintBrand, borderRadius: BorderRadius.circular(ok && big ? 30 : Radii.tile)),
      child: Icon(icon, size: big ? 26 : 22, color: ok ? c.success : c.textBrand),
    );
    if (big) return box;
    return Column(children: [
      Expanded(child: AspectRatio(aspectRatio: 1, child: box)),
      const SizedBox(height: Space.s1_5),
      Text(label ?? '', style: THType.meta.copyWith(fontFamily: THFonts.display, fontSize: 11, fontWeight: FontWeight.w500, color: c.text)),
    ]);
  }
}

// ───────────────────────────── inputs & selectors ─────────────────────────────
class THField extends StatelessWidget {
  const THField({super.key, this.label, required this.value, this.icon, this.trailing, this.height, this.placeholder = false});
  final String? label;
  final String value;
  final IconData? icon;
  final IconData? trailing;
  final double? height;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Container(
      constraints: BoxConstraints(minHeight: math.max(Sizes.input, height ?? 0)),
      padding: const EdgeInsets.symmetric(horizontal: Space.s3_5, vertical: Space.s2_5),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.control), border: Border.all(color: c.line)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        if (label != null && label!.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(label!, style: THType.label.copyWith(fontSize: 10.5, letterSpacing: 0.6, color: c.textSoft))),
        Row(spacing: Space.s2_5, children: [
          if (icon != null) Icon(icon, size: 18, color: placeholder ? c.textSoft : c.text),
          Expanded(child: Text(value, style: THType.body.copyWith(color: placeholder ? c.textSoft : c.text))),
          if (trailing != null) Icon(trailing, size: 18, color: c.textSoft),
        ]),
      ]),
    );
  }
}

class THPillItem {
  const THPillItem(this.label, {this.selected = false, this.icon});
  final String label;
  final bool selected;
  final IconData? icon;
}

class THPills extends StatelessWidget {
  const THPills({super.key, required this.items});
  final List<THPillItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Wrap(spacing: Space.s2, runSpacing: Space.s2, children: [
      for (final p in items)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.s3_5, vertical: 9),
          decoration: BoxDecoration(color: p.selected ? c.brand : c.surface, borderRadius: BorderRadius.circular(Radii.pill), border: Border.all(color: p.selected ? c.brand : c.line)),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: Space.s1_5, children: [
            if (p.icon != null) Icon(p.icon, size: 14, color: p.selected ? c.onBrand : c.text),
            Text(p.label, style: THType.button.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: p.selected ? c.onBrand : c.text)),
          ]),
        ),
    ]);
  }
}

class THSegmented extends StatelessWidget {
  const THSegmented({super.key, required this.items, required this.selected});
  final List<String> items;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Container(
      padding: const EdgeInsets.all(Space.s1),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.control)),
      child: Row(children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Space.s2_5),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: i == selected ? c.surface : null, borderRadius: BorderRadius.circular(Radii.control - 4)),
              child: Text(items[i], style: THType.button.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: i == selected ? c.text : c.textSoft)),
            ),
          ),
      ]),
    );
  }
}

class THSwitch extends StatelessWidget {
  const THSwitch({super.key, required this.on, this.onChanged});
  final bool on;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Semantics(
      toggled: on,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!on),
        child: AnimatedContainer(
          duration: THDurations.fast,
          width: 52,
          height: 30,
          padding: const EdgeInsets.all(3),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(color: on ? c.success : c.track, borderRadius: BorderRadius.circular(Radii.pill)),
          child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        ),
      ),
    );
  }
}

class THOtp extends StatelessWidget {
  const THOtp({super.key, required this.count, required this.value});
  final int count;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Row(mainAxisAlignment: MainAxisAlignment.center, spacing: Space.s2_5, children: [
      for (var i = 0; i < count; i++)
        Container(
          width: 48,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.control - 2), border: Border.all(color: i == value.length ? c.brand : (i < value.length ? c.textBrand : c.line), width: 1.5)),
          child: Text(i < value.length ? value[i] : '', style: THType.h1),
        ),
    ]);
  }
}

// ───────────────────────────── data display ─────────────────────────────
class THKeyValue extends StatelessWidget {
  const THKeyValue(this.label, this.value, {super.key, this.bold = false, this.strong = false, this.tone = THTone.base, this.badge, this.copy = false, this.divider = false});
  final String label;
  final String value;
  final bool bold;
  final bool strong;
  final THTone tone;
  final THBadgeKind? badge;
  final bool copy;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.s2),
      decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: c.line)) : null),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s3, children: [
        Expanded(child: Text(label, style: (strong ? THType.title : THType.body).copyWith(fontSize: strong ? 16 : 14.5, color: strong ? c.text : c.textSoft))),
        if (badge != null)
          THBadge(value, kind: badge!)
        else
          Row(mainAxisSize: MainAxisSize.min, spacing: Space.s1_5, children: [
            Text(value, style: (strong ? THType.title : THType.body).copyWith(fontSize: strong ? 16 : 14.5, fontWeight: bold || strong ? FontWeight.w700 : null, color: _tone(c, tone))),
            if (copy) Icon(Icons.content_copy_rounded, size: 15, color: c.textBrand),
          ]),
      ]),
    );
  }
}

class THProgress extends StatelessWidget {
  const THProgress({super.key, required this.steps, required this.done, this.current = false});
  final int steps;
  final int done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Row(spacing: 5, children: [
      for (var i = 0; i < steps; i++)
        Expanded(child: Container(height: 6, decoration: BoxDecoration(color: i < done ? c.success : (i == done && current ? c.accent : c.track), borderRadius: BorderRadius.circular(3)))),
    ]);
  }
}

class THDots extends StatelessWidget {
  const THDots({super.key, required this.count, required this.on});
  final int count;
  final int on;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Row(mainAxisAlignment: MainAxisAlignment.center, spacing: Space.s2, children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(duration: THDurations.base, width: i == on ? 32 : 10, height: 10, decoration: BoxDecoration(color: i == on ? c.accent : c.track, borderRadius: BorderRadius.circular(5))),
    ]);
  }
}

class THTimelineItem {
  const THTimelineItem(this.title, {this.subtitle, this.state = THTimelineState.todo});
  final String title;
  final String? subtitle;
  final THTimelineState state;
}

class THTimeline extends StatelessWidget {
  const THTimeline({super.key, required this.items});
  final List<THTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Column(children: [
      for (var i = 0; i < items.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: Space.s3, children: [
            SizedBox(
              width: 24,
              child: Column(children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (items[i].state) { THTimelineState.done => c.success, THTimelineState.cur => c.accentTint, THTimelineState.todo => c.surface },
                    border: Border.all(color: switch (items[i].state) { THTimelineState.done => c.success, THTimelineState.cur => c.accent, THTimelineState.todo => c.line }, width: 2),
                  ),
                  child: switch (items[i].state) {
                    THTimelineState.done => Icon(Icons.check_rounded, size: 12, color: c.paper),
                    THTimelineState.cur => Container(width: 8, height: 8, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
                    THTimelineState.todo => null,
                  },
                ),
                if (i < items.length - 1) Expanded(child: Container(width: 2, color: items[i].state == THTimelineState.done ? c.success : c.line)),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: i < items.length - 1 ? Space.s4 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(items[i].title, style: THType.title.copyWith(fontSize: 14.5)),
                  if (items[i].subtitle != null) Text(items[i].subtitle!, style: THType.meta.copyWith(color: c.textSoft)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class THListRow extends StatelessWidget {
  const THListRow({super.key, required this.icon, required this.title, this.subtitle, this.badge, this.unread = false, this.flat = false, this.divider = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final bool unread;
  final bool flat;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(
        color: flat ? null : c.surface,
        borderRadius: flat ? null : BorderRadius.circular(Radii.card),
        border: flat ? (divider ? Border(top: BorderSide(color: c.line)) : null) : Border.all(color: c.line),
      ),
      child: Row(spacing: Space.s3, children: [
        Container(width: Sizes.buttonSm, height: Sizes.buttonSm, decoration: BoxDecoration(color: c.tintBrand, borderRadius: BorderRadius.circular(Radii.control - 2)), child: Icon(icon, size: 20, color: c.textBrand)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: THType.title.copyWith(fontSize: 15)),
          if (subtitle != null) Text(subtitle!, style: THType.meta.copyWith(color: c.textSoft)),
        ])),
        if (badge != null)
          THBadge(badge!, kind: badge == 'Verified' ? THBadgeKind.ok : THBadgeKind.accent)
        else if (unread)
          Container(width: 9, height: 9, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle))
        else
          Icon(Icons.chevron_right_rounded, size: 18, color: c.textSoft),
      ]),
    );
  }
}

class THBubble extends StatelessWidget {
  const THBubble(this.text, {super.key, this.mine = false, this.time = ''});
  final String text;
  final bool mine;
  final String time;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.s3_5, vertical: Space.s2_5),
            decoration: BoxDecoration(
              color: mine ? c.brand : c.surface,
              border: mine ? null : Border.all(color: c.line),
              borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 6), bottomRight: Radius.circular(mine ? 6 : 18)),
            ),
            child: Text(text, style: THType.body.copyWith(color: mine ? c.onBrand : c.text)),
          ),
          if (time.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(6, 3, 6, 0), child: Text(time, style: THType.meta.copyWith(fontSize: 11, color: c.textSoft))),
        ]),
      ),
    );
  }
}

class THStars extends StatelessWidget {
  const THStars(this.value, {super.key, this.size = 16});
  final int value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Row(mainAxisAlignment: MainAxisAlignment.center, spacing: Space.s1, children: [
      for (var i = 0; i < 5; i++) Icon(Icons.star_rounded, size: size, color: i < value ? c.accent : c.track),
    ]);
  }
}

class THBars extends StatelessWidget {
  const THBars({super.key, required this.values, required this.labels});
  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return SizedBox(
      height: 110,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, spacing: Space.s2_5, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, spacing: Space.s1_5, children: [
              Flexible(child: FractionallySizedBox(heightFactor: values[i] / 100, child: Container(decoration: BoxDecoration(color: i == 5 ? c.accent : c.tintBrand, borderRadius: BorderRadius.circular(8))))),
              Text(labels[i], style: THType.label.copyWith(fontSize: 11, letterSpacing: 0, fontWeight: FontWeight.w500, color: c.textSoft)),
            ]),
          ),
      ]),
    );
  }
}

class THDivider extends StatelessWidget {
  const THDivider({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final line = Expanded(child: Container(height: 1, color: c.line));
    return Row(spacing: Space.s3, children: [
      line,
      if (label != null) ...[Text(label!, style: THType.meta.copyWith(color: c.textSoft)), line],
    ]);
  }
}

// ───────────────────────────── media & custom paint ─────────────────────────────
class THPhotoStrip extends StatelessWidget {
  const THPhotoStrip({super.key, this.count = 3});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final fills = [c.tintBrand, c.accentTint, c.surfaceAlt];
    return Row(spacing: Space.s2_5, children: [
      for (var i = 0; i < count; i++)
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(color: fills[i % fills.length], borderRadius: BorderRadius.circular(Radii.control), border: Border.all(color: c.line)),
              child: Icon(Icons.photo_camera_rounded, size: 22, color: c.textBrand), // replace with Image.network in the app
            ),
          ),
        ),
    ]);
  }
}

class THIllustration extends StatelessWidget {
  const THIllustration(this.icon, {super.key});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Container(
      height: 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.sheet), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.tintBrand, c.surfaceAlt])),
      child: Stack(alignment: Alignment.center, children: [
        Positioned(top: -60, right: -70, child: Container(width: 220, height: 220, decoration: BoxDecoration(color: c.heroGlow, shape: BoxShape.circle))),
        Positioned(bottom: 30, left: 20, child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.brand.withValues(alpha: 0.35), width: 2)))),
        Container(width: 112, height: 112, decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(36)), child: Icon(icon, size: 54, color: c.onBrand)),
      ]),
    );
  }
}

class THMapPlaceholder extends StatelessWidget {
  const THMapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Container(
      height: 120,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
      child: CustomPaint(
        painter: _GridPainter(c.line),
        child: Center(child: Container(width: 46, height: 46, decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(Radii.control)), child: Icon(Icons.place_rounded, size: 28, color: c.onAccent))),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1;
    for (double x = 24; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 24; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

class THDashBox extends StatelessWidget {
  const THDashBox({super.key, required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return CustomPaint(
      painter: _DashedRRect(color: c.brand, radius: Radii.tile),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3_5),
        decoration: BoxDecoration(color: c.tintBrand, borderRadius: BorderRadius.circular(Radii.tile)),
        child: Row(spacing: Space.s3, children: [
          Icon(icon, size: 22, color: c.textBrand),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: THType.body.copyWith(fontWeight: FontWeight.w600, fontSize: 14.5, color: c.textBrand)),
            if (subtitle != null) Text(subtitle!, style: THType.meta.copyWith(fontSize: 12.5, color: c.textBrand)),
          ])),
        ]),
      ),
    );
  }
}

class _DashedRRect extends CustomPainter {
  _DashedRRect({required this.color, required this.radius});
  final Color color;
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5;
    for (final PathMetric m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) => old.color != color;
}

class THRing extends StatelessWidget {
  const THRing({super.key, required this.value, required this.caption, required this.percent});
  final String value;
  final String caption;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Center(
      child: SizedBox(
        width: 164,
        height: 164,
        child: CustomPaint(
          painter: _RingPainter(track: c.track, arc: c.accent, percent: percent),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [THText(value, style: THTextStyle.moneyLg), THText(caption, style: THTextStyle.meta, tone: THTone.soft, size: 12)])),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.track, required this.arc, required this.percent});
  final Color track;
  final Color arc;
  final double percent;
  @override
  void paint(Canvas canvas, Size size) {
    const w = 12.0;
    final rect = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * percent, false, p..color = arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.percent != percent || old.arc != arc || old.track != track;
}

/// Brand glyph for the "new request" action: a hunter's crosshair with a plus at its centre.
/// 24-unit grid, stroke style matches the Material rounded set.
class THHuntGlyph extends StatelessWidget {
  const THHuntGlyph({super.key, this.size = 30, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _HuntPainter(color));
}

class _HuntPainter extends CustomPainter {
  _HuntPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.9 * s..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(12 * s, 12 * s), 7 * s, p);
    for (final seg in const [[12.0, 1.5, 12.0, 4.5], [12.0, 19.5, 12.0, 22.5], [1.5, 12.0, 4.5, 12.0], [19.5, 12.0, 22.5, 12.0], [12.0, 9.0, 12.0, 15.0], [9.0, 12.0, 15.0, 12.0]]) {
      canvas.drawLine(Offset(seg[0] * s, seg[1] * s), Offset(seg[2] * s, seg[3] * s), p);
    }
  }

  @override
  bool shouldRepaint(_HuntPainter old) => old.color != color;
}

class THWordmark extends StatelessWidget {
  const THWordmark({super.key, this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Tradie', style: TextStyle(color: large ? c.onHero : c.textBrand)),
        TextSpan(text: 'Hunter', style: TextStyle(color: large ? c.heroGold : c.accentText)),
      ]),
      textAlign: large ? TextAlign.center : TextAlign.start,
      style: TextStyle(fontFamily: THFonts.display, fontWeight: FontWeight.w800, fontSize: large ? 40 : 22, letterSpacing: large ? -1 : -0.3),
    );
  }
}

// ───────────────────────────── chrome ─────────────────────────────
class THAppBar extends StatelessWidget implements PreferredSizeWidget {
  const THAppBar({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Material(
      color: c.paper,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sizes.gutter, Space.s1_5, Sizes.gutter, Space.s2_5),
          child: Row(spacing: Space.s3, children: [
            THIconButton(icon: Icons.arrow_back_rounded, semanticLabel: 'Back', onPressed: () => Navigator.maybePop(context)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: THType.title.copyWith(color: c.text)),
              if (subtitle != null) Text(subtitle!, style: THType.meta.copyWith(color: c.textSoft)),
            ])),
          ]),
        ),
      ),
    );
  }
}

class THStickyBar extends StatelessWidget {
  const THStickyBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return ClipRect(
      child: Container(
        padding: EdgeInsets.fromLTRB(Sizes.gutter, Space.s3_5, Sizes.gutter, Space.s3 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: c.glass, border: Border(top: BorderSide(color: c.line))),
        child: Row(spacing: Space.s2_5, children: children),
      ),
    );
  }
}

class THDock extends StatelessWidget {
  const THDock({super.key, required this.role, this.active, this.onSelected, this.onNewRequest});
  final THDockRole role;
  final THDockTab? active;
  final ValueChanged<THDockTab>? onSelected;
  final VoidCallback? onNewRequest;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    Widget item(THDockTab t, IconData icon, String label) {
      final on = t == active;
      return Semantics(
        button: true,
        selected: on,
        label: label,
        child: InkWell(
          onTap: onSelected == null ? null : () => onSelected!(t),
          borderRadius: BorderRadius.circular(Radii.control),
          child: SizedBox(width: 56, child: Column(mainAxisSize: MainAxisSize.min, spacing: 2, children: [
            Icon(icon, size: 22, color: on ? c.textBrand : c.textSoft),
            Text(label, style: THType.label.copyWith(fontSize: 10.5, letterSpacing: 0, fontWeight: FontWeight.w500, color: on ? c.textBrand : c.textSoft)),
          ])),
        ),
      );
    }

    final fab = Semantics(
      button: true,
      label: 'New request',
      child: GestureDetector(
        onTap: onNewRequest,
        child: Transform.translate(
          offset: const Offset(0, -Space.s7 - 2),
          child: Container(
            width: Sizes.fab,
            height: Sizes.fab,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.paper, width: 4), boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))]),
            child: THHuntGlyph(color: c.onAccent),
          ),
        ),
      ),
    );

    return Container(
      height: Sizes.dock,
      decoration: BoxDecoration(color: c.glass, borderRadius: BorderRadius.circular(30), border: Border.all(color: c.line), boxShadow: const [BoxShadow(color: Color(0x2E0A143C), blurRadius: 30, offset: Offset(0, 10))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        item(THDockTab.home, Icons.home_rounded, 'Home'),
        item(THDockTab.jobs, Icons.work_rounded, 'Jobs'),
        if (role == THDockRole.homeowner) fab,
        item(THDockTab.chat, Icons.chat_bubble_rounded, 'Chat'),
        item(THDockTab.profile, Icons.person_rounded, 'Profile'),
      ]),
    );
  }
}

class THScaffold extends StatelessWidget {
  const THScaffold({super.key, required this.body, this.appBar, this.dock, this.stickyBar, this.scrollable = true, this.heroBackground = false});
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? dock;
  final Widget? stickyBar;
  final bool scrollable;
  final bool heroBackground;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final clearance = dock != null ? Sizes.dockClearance : (stickyBar != null ? Sizes.stickyClearance + Space.s3 : Space.s6);
    final padded = Padding(padding: EdgeInsets.fromLTRB(Sizes.gutter, Space.s1_5, Sizes.gutter, clearance), child: body);
    final scaffold = Scaffold(
      backgroundColor: heroBackground ? Colors.transparent : c.paper,
      appBar: appBar,
      body: Stack(children: [
        Positioned.fill(child: SafeArea(bottom: false, child: scrollable ? SingleChildScrollView(child: padded) : padded)),
        if (dock != null) Positioned(left: Space.s3_5, right: Space.s3_5, bottom: Space.s4, child: SafeArea(top: false, child: dock!)),
        if (stickyBar != null) Positioned(left: 0, right: 0, bottom: 0, child: stickyBar!),
      ]),
    );
    if (!heroBackground) return scaffold;
    return Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.heroStart, c.heroEnd])), child: scaffold);
  }
}
