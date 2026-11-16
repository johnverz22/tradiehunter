# kit.css → Flutter (TradieHunter design system v1.7)

| kit.css | Flutter | Token / note |
|---|---|---|
| `--gutter:20px` | `Space.gutter` | screen horizontal padding |
| `--s1..s8` 4/8/12/16/20/24/32/40 | `Space.s1,s2,s3,s4,s5,s6,s7,s8` | |
| card radius 20 / control 14 / tile 16 / sheet 28 / pill 999 | `Radii.card/control/tile/sheet/pill` | |
| `.appbar` 56px, `.back` 48×48 | `FixoAppBar` | height `Sizes.appBar`; glyph `Sizes.iconLg` (24); target `Sizes.tapMin` |
| `.pill` 28px 13/600 | `StatusBadge(FixoBadgeKind.…)` | kinds: actionNeeded, active, waiting, done, cancelled, problem |
| `.badge` 26px 12/600 | status/trust label (see recipes) | non-interactive, wraps |
| `.chip` 40px (hit 48) | `ChoiceChip`/custom with `Sizes.chipVisual` + `Sizes.tapMin` hit | interactive only |
| `.faderow` | horizontal `ListView` + `ShaderMask` fade | last ~32dp |
| `.filters` equal columns | `Row` of `Expanded` | 4 chips fit |
| `.sticky` bottom CTA | `bottomNavigationBar`/`SafeArea` bar, content padded `Space.stickyBarClearance` | |
| `.btn-primary` 56 / secondary 52 / tonal, ghost 48 | `FixoPrimaryButton` / `FixoGhostButton` / `FixoTonalButton` | one amber primary per screen |
| `.btn-tile` icon-over-label 64 | shared `ActionTileRow` (Navigate/Message/Call) | equal columns |
| `.heroband` | `FixoHeaderBackground` / `FixoGradientTopArea` | white glyphs |
| `.maphead` back | circular scrim 44dp, white 78% | outdoor: flat + outline |
| `.spread` | `Row(mainAxisAlignment: spaceBetween)` | never for 3+ labels |
| `.row` | `Row` + `SizedBox(width: Space.s2_5)` | gap 10 |
| `.sec`/caption 12 | `DesignTokens.fontSizeCaption` | never below 12 |
