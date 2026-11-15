import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class NavTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavTab(this.icon, this.activeIcon, this.label);
}

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onPostJob;
  final bool showFab;
  final List<NavTab> tabs;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onPostJob,
    required this.tabs,
    this.showFab = false,
  });

  static const homeownerTabs = [
    NavTab(Icons.home_outlined, Icons.home, 'Home'),
    NavTab(Icons.work_outline, Icons.work, 'Jobs'),
    NavTab(Icons.chat_outlined, Icons.chat, 'Messages'),
    NavTab(Icons.person_outline, Icons.person, 'Profile'),
  ];

  static const tradieTabs = [
    NavTab(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    NavTab(Icons.work_outline, Icons.work, 'Jobs'),
    NavTab(Icons.chat_outlined, Icons.chat, 'Messages'),
    NavTab(Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    if (showFab) {
      return _buildHomeownerDock(context, isDark, bottomPad);
    }
    return _buildTradieDock(context, isDark, bottomPad);
  }

  /// Homeowner dock — mockup `nav/bottom-homeowner` (component-sheet.html):
  /// a 68px glass bar (`--glass rgba(255,255,255,.86)`, backdrop blur 20)
  /// with the 56px New Job FAB straddling its top edge (`.fab { top: -26px }`)
  /// — half in, half out, horizontally centred over the empty third slot.
  Widget _buildHomeownerDock(
    BuildContext context,
    bool isDark,
    double bottomPad,
  ) {
    // --glass: rgba(255,255,255,.86) light / rgba(30,35,40,.86) dark.
    final bgColor = isDark
        ? DesignTokens.cardDark.withValues(alpha: Alpha.glass)
        : Colors.white.withValues(alpha: Alpha.glass);
    final borderColor = DesignTokens.paperLine(isDark);

    // Split the 4 tabs around the centre FAB slot.
    // tabs = [Home, Jobs, Messages, Profile] → left: [0,1], right: [2,3]
    final leftTabs = tabs.sublist(0, tabs.length ~/ 2);
    final rightTabs = tabs.sublist(tabs.length ~/ 2);

    // Top padding reserves room for the FAB's upper half above the tabs.
    final halfFab = Sizes.fab / 2;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // ── The glass bar itself ─────────────────────────────────────────
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(top: BorderSide(color: borderColor)),
                boxShadow: [
                  BoxShadow(
                    color: DesignTokens.brand900.withValues(
                      alpha: Alpha.subtle,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.zero,
              child: SafeArea(
                top: false,
                child: Padding(
                  // Top pad lifts the tabs clear of the FAB's lower half.
                  padding: EdgeInsets.fromLTRB(
                    Space.s3,
                    halfFab + Space.s2,
                    Space.s3,
                    Space.s2,
                  ),
                  child: Row(
                    children: [
                      // Left tabs
                      for (var i = 0; i < leftTabs.length; i++)
                        Expanded(
                          child: _TradieNavItem(
                            tab: leftTabs[i],
                            selected: currentIndex == i,
                            onTap: () => onDestinationSelected(i),
                          ),
                        ),
                      // Centre slot stays empty — the FAB overlay owns it.
                      const Expanded(child: SizedBox()),
                      // Right tabs (offset indices by left count)
                      for (var i = 0; i < rightTabs.length; i++)
                        Expanded(
                          child: _TradieNavItem(
                            tab: rightTabs[i],
                            selected: currentIndex == (leftTabs.length + i),
                            onTap: () =>
                                onDestinationSelected(leftTabs.length + i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // ── New Job FAB — straddles the bar's top edge (.fab top:-26px) ───
        Positioned(
          top: 0,
          child: Transform.translate(
            offset: Offset(0, -halfFab + 2),
            child: _NewJobNavItem(onTap: onPostJob),
          ),
        ),
      ],
    );
  }

  Widget _buildTradieDock(BuildContext context, bool isDark, double bottomPad) {
    // --glass: rgba(255,255,255,.86) light / rgba(30,35,40,.86) dark.
    final bgColor = isDark
        ? DesignTokens.cardDark.withValues(alpha: Alpha.glass)
        : Colors.white.withValues(alpha: Alpha.glass);
    final borderColor = DesignTokens.paperLine(isDark);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(top: BorderSide(color: borderColor)),
            boxShadow: [
              BoxShadow(
                color: DesignTokens.brand900.withValues(alpha: Alpha.subtle),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.zero,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.s3,
                Space.s2_5,
                Space.s3,
                Space.s2,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: _TradieNavItem(
                        tab: tabs[i],
                        selected: currentIndex == i,
                        onTap: () => onDestinationSelected(i),
                        badge: null,
                        dot: false,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TradieNavItem extends StatelessWidget {
  final NavTab tab;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final bool dot;

  const _TradieNavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.badge,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? DesignTokens.inkDark : DesignTokens.brand900;
    final inactiveColor = DesignTokens.inkSoft(isDark);
    final color = selected ? activeColor : inactiveColor;

    return Semantics(
      selected: selected,
      button: true,
      child: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64, minWidth: 48),
          child: InkResponse(
            onTap: onTap,
            radius: 32,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Space.s1),
                      decoration: selected
                          ? BoxDecoration(
                              color: activeColor.withValues(
                                alpha: Alpha.tintLight,
                              ),
                              borderRadius: BorderRadius.circular(Radii.medium),
                            )
                          : null,
                      child: Icon(
                        selected ? tab.activeIcon : tab.icon,
                        size: 26,
                        color: selected ? activeColor : color,
                        fill: selected ? 1.0 : 0.0,
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        top: -2,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.s1,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          decoration: BoxDecoration(
                            color: DesignTokens.brand900,
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                badge!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: DesignTokens.fontSizeCaption,
                                  fontWeight: FW.bold,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (dot && !selected)
                      Positioned(
                        top: 2,
                        right: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: DesignTokens.amber,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Space.s1),
                Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: DesignTokens.fontBody,
                    fontSize: DesignTokens.fontSizeCaption,
                    fontWeight: selected ? FW.bold : FW.medium,
                    letterSpacing: Tracking.tightSm * 11,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Centre "New Job" FAB for the homeowner dock — mockup `.fab`:
/// 56×56, border-radius 18px, navy fill, white 26px plus glyph, 3px paper
/// border, `0 6px 16px rgba(25,57,87,.28)` shadow. Rendered inside the
/// bar's Stack so it straddles the top edge (`.fab { top: -26px }`);
/// tapping pushes /jobs/new via [onPostJob].
class _NewJobNavItem extends StatelessWidget {
  final VoidCallback onTap;

  const _NewJobNavItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'Post job',
      child: Tooltip(
        message: 'Post job',
        child: InkResponse(
          key: const Key('post_job_fab'),
          onTap: onTap,
          radius: Sizes.fab / 2 + 8,
          child: Container(
            width: Sizes.fab,
            height: Sizes.fab,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: DesignTokens.brand900,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : DesignTokens.brand900.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? DesignTokens.paperDark
                    : DesignTokens.paperLight,
                width: 3,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.add, size: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
