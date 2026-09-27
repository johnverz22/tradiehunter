import 'dart:ui';

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// Data for one side destination in [CustomBottomNavBar].
///
/// Pure display data — no navigation logic lives here. The screen that
/// owns [CustomBottomNavBar] keeps deciding `currentIndex` and what
/// `onDestinationSelected(index)` actually does (e.g. `context.go(...)`),
/// exactly like the plain [NavigationBar] it replaces.
class CustomNavBarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const CustomNavBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Modern, glassmorphic, floating/docked bottom navigation bar with a
/// raised, glowing "Post Job" action centered in the dock.
///
/// Drop-in visual replacement for a [NavigationBar]: it does not own any
/// navigation state. Pass the same `currentIndex` / `onDestinationSelected`
/// callback you already wire to your router, and the same FAB
/// `onPressed` you already use for `context.push('/jobs/new')`.
///
/// [items] are split evenly left/right around the center FAB — with an
/// odd count, the extra item goes on the left. This mirrors the tab
/// layouts in `main_layout.dart` (3 tabs for homeowners, 4 for tradies)
/// without hardcoding either role's tab list here.
class CustomBottomNavBar extends StatelessWidget {
  final List<CustomNavBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Callback for the centered action button. Kept separate from
  /// [onDestinationSelected] because "Post Job" is an action, not a tab
  /// — same as the existing `FloatingActionButton.extended` it replaces.
  final VoidCallback onFabPressed;
  final IconData fabIcon;
  final String? fabTooltip;

  /// Whether the FAB should render as active/inflated (e.g. while a
  /// posting flow is open). Purely visual.
  final bool fabActive;

  const CustomBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onFabPressed,
    this.fabIcon = Icons.add_rounded,
    this.fabTooltip = 'Post a Job',
    this.fabActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final left = <CustomNavBarItem>[];
    final right = <CustomNavBarItem>[];
    for (var i = 0; i < items.length; i++) {
      final targetLeft = i <= (items.length - 1) / 2;
      (targetLeft ? left : right).add(items[i]);
    }
    final leftCount = left.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset > 0 ? bottomInset : 16),
      child: SizedBox(
        height: 76,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // ── Frosted glass dock ────────────────────────────────────
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: (isDark ? DesignTokens.cardDark : Colors.white)
                          .withValues(alpha: isDark ? 0.55 : 0.65),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.white)
                            .withValues(alpha: isDark ? 0.08 : 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < left.length; i++)
                          _NavIcon(
                            item: left[i],
                            selected: currentIndex == i,
                            onTap: () => onDestinationSelected(i),
                          ),
                        // Gap the centered FAB floats above.
                        const SizedBox(width: 64),
                        for (var i = 0; i < right.length; i++)
                          _NavIcon(
                            item: right[i],
                            selected: currentIndex == leftCount + i,
                            onTap: () => onDestinationSelected(leftCount + i),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Centered glowing "Post Job" FAB ───────────────────────
            Positioned(
              top: -22,
              child: Semantics(
                button: true,
                label: fabTooltip,
                child: GestureDetector(
                  onTap: onFabPressed,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          DesignTokens.amber,
                          DesignTokens.amberDark,
                        ],
                      ),
                      boxShadow: [
                        // Outer glow ring in the brand accent color.
                        BoxShadow(
                          color: DesignTokens.amber
                              .withValues(alpha: fabActive ? 0.55 : 0.40),
                          blurRadius: 22,
                          spreadRadius: fabActive ? 4 : 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: (isDark ? DesignTokens.paperDark : Colors.white)
                            .withValues(alpha: 0.9),
                        width: 3,
                      ),
                    ),
                    child: Icon(fabIcon, color: DesignTokens.onAmber, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final CustomNavBarItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavIcon({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? DesignTokens.brand500 : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? item.selectedIcon : item.icon, color: color, size: 24),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  fontFamily: DesignTokens.fontMono,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
