import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/design_tokens.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../widgets/fixo_states.dart' show kBreakpointLeftRail;
import 'widgets/custom_bottom_nav_bar.dart';

/// Adaptive navigation shell — role-aware nav that switches between:
/// - Bottom tab bar (phone / ≤1023pt)
/// - Left navigation rail (tablet landscape / ≥1024pt)
///
/// Role is read from [profileViewModelProvider] instead of sniffing the URL
/// so a tradie who happens to visit a non-/tradie path still sees the right
/// nav items.
///
/// Visual layer: the bottom bar is the glassmorphic [CustomBottomNavBar].
/// The left rail uses the standard Material [NavigationRail] styled to match
/// the Fixo design tokens.
class MainLayout extends ConsumerWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileViewModelProvider);
    final location = GoRouterState.of(context).uri.path;
    final width = MediaQuery.sizeOf(context).width;

    // role == 1 → Tradie. Any other value → Homeowner nav.
    final isTradie = profileState.profile?['role'] == 1;
    final useRail = width >= kBreakpointLeftRail;

    if (isTradie) {
      int currentIndex = 0;
      if (location.startsWith('/jobs')) {
        currentIndex = 1;
      } else if (location.startsWith('/messages') || location.startsWith('/chat')) {
        currentIndex = 2;
      } else if (location.startsWith('/profile') || location.startsWith('/settings')) {
        currentIndex = 3;
      }

      void navigate(int index) {
        switch (index) {
          case 0: context.go('/tradie');
          case 1: context.go('/jobs');
          case 2: context.go('/messages');
          case 3: context.go('/profile');
        }
      }

      if (useRail) {
        return Scaffold(
          body: Row(
            children: [
              _FixoNavRail(
                currentIndex: currentIndex,
                tabs: CustomBottomNavBar.tradieTabs,
                showPostJob: false,
                onDestinationSelected: navigate,
                onPostJob: () => context.push('/jobs/new'),
              ),
              Expanded(child: child),
            ],
          ),
        );
      }

      return Scaffold(
        body: child,
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: currentIndex,
          tabs: CustomBottomNavBar.tradieTabs,
          showFab: false,
          onDestinationSelected: navigate,
          onPostJob: () => context.push('/jobs/new'),
        ),
      );
    }

    // Homeowner nav: Home / Jobs / Messages / Profile (+ Post Job action).
    int currentIndex = 0;
    if (location.startsWith('/jobs')) {
      currentIndex = 1;
    } else if (location.startsWith('/messages') || location.startsWith('/chat')) {
      currentIndex = 2;
    } else if (location.startsWith('/profile') || location.startsWith('/settings')) {
      currentIndex = 3;
    }

    void navigate(int index) {
      switch (index) {
        case 0: context.go('/home');
        case 1: context.go('/jobs');
        case 2: context.go('/messages');
        case 3: context.go('/profile');
      }
    }

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            _FixoNavRail(
              currentIndex: currentIndex,
              tabs: CustomBottomNavBar.homeownerTabs,
              showPostJob: true,
              onDestinationSelected: navigate,
              onPostJob: () => context.push('/jobs/new'),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: currentIndex,
        tabs: CustomBottomNavBar.homeownerTabs,
        showFab: true,
        onDestinationSelected: navigate,
        onPostJob: () => context.push('/jobs/new'),
      ),
    );
  }
}

// ─── Left navigation rail ──────────────────────────────────────────────────

/// 64px-wide left navigation rail shown at ≥[kBreakpointLeftRail] width.
///
/// Renders the same [tabs] as the bottom bar, plus an optional "Post Job"
/// amber action button for homeowners. Styled with Fixo design tokens.
class _FixoNavRail extends StatelessWidget {
  final int currentIndex;
  final List<NavTab> tabs;
  final bool showPostJob;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onPostJob;

  const _FixoNavRail({
    required this.currentIndex,
    required this.tabs,
    required this.showPostJob,
    required this.onDestinationSelected,
    required this.onPostJob,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor =
        isDark ? DesignTokens.cardDark : DesignTokens.paperLight;
    final borderColor = DesignTokens.paperLine(isDark);
    final activeColor = DesignTokens.brand900;
    final inactiveColor = DesignTokens.inkSoft(isDark);

    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: Space.s4),
            // Post Job action (homeowner only)
            if (showPostJob) ...[
              _RailPostJobButton(onTap: onPostJob),
              const SizedBox(height: Space.s2),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: Space.s2),
            ],
            // Navigation items
            for (var i = 0; i < tabs.length; i++) ...[
              _RailItem(
                tab: tabs[i],
                selected: currentIndex == i,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => onDestinationSelected(i),
              ),
              const SizedBox(height: Space.s1),
            ],
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final NavTab tab;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _RailItem({
    required this.tab,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;

    return Semantics(
      label: tab.label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.medium),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s2, vertical: Space.s2),
          child: SizedBox(
            width: 56,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(Space.s1),
                  decoration: selected
                      ? BoxDecoration(
                          color: activeColor.withValues(alpha: Alpha.tintLight),
                          borderRadius: BorderRadius.circular(Radii.small),
                        )
                      : null,
                  child: Icon(
                    selected ? tab.activeIcon : tab.icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: DesignTokens.fontBody,
                    fontSize: DesignTokens.fontSizeCaption,
                    fontWeight:
                        selected ? FW.bold : FW.medium,
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

class _RailPostJobButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RailPostJobButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Post job',
      child: Tooltip(
        message: 'Post job',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.sheet),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DesignTokens.amber,
              boxShadow: [
                BoxShadow(
                  color: DesignTokens.shadowCard,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.post_add_outlined,
              size: 24,
              color: DesignTokens.onAmber,
            ),
          ),
        ),
      ),
    );
  }
}

