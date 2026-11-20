// ThShell: the v2 navigation shell (migration plan 3.1).
//
// Mirrors views/main_layout.dart exactly at the behavioural level:
//   • role from profileViewModelProvider (`profile['role'] == 1` → tradie)
//   • prefix-based active-tab detection (/jobs*, /messages*|/chat*, /profile*|/settings*)
//   • role-dependent landing route (tab 0 → /tradie or /home)
//   • homeowner-only centre action → context.push('/jobs/new')
//   • wide layout (≥1024): left rail replica in TH tokens
//   • narrow layout: Column(Expanded(child), THDock): full-bleed bar flush
//     with the bottom edge; routed content ends where the bar begins
//
// Visual layer is the v2 THDock / TH tokens instead of CustomBottomNavBar.
// The rail is a needs-design stand-in (D-4): TH tokens, same structure as the
// v1 _FixoNavRail.
//
// The routed child is NOT wrapped in ThScope: v1 children (dashboards, jobs
// list) keep FixoTheme until their phases land, and v2 children wrap
// themselves in ThScope per the §4.0 recipe. Only the shell chrome is themed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'chat_unread_provider.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';

/// One-off: matches the v1 rail breakpoint (`kBreakpointLeftRail`); the v1
/// constant lives in widgets/fixo_states.dart, which ui/** cannot import.
const double kThBreakpointLeftRail = 1024.0;

/// One-off: matches the v1 master-detail breakpoint used by the messages
/// inbox (744.0). Lives here so both v2 messages screens share it.
const double kThBreakpointMasterDetail = 744.0;

/// One-off: matches the v1 rail width (72px; the v1 doc comment says 64 but
/// the code renders 72 — the v2 rail copies the rendered reality).
const double kThRailWidth = 72.0;

/// One-off: matches the v1 chat max content width (kMaxContentWidth = 640).
const double kThMaxContentWidth = 640.0;

/// The v2 shell. Swap point: the ShellRoute builder branches on
/// `isV2Screen('shell')` and either builds this or v1 [MainLayout].
class ThShell extends ConsumerStatefulWidget {
  const ThShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ThShell> createState() => _ThShellState();
}

class _ThShellState extends ConsumerState<ThShell> {
  String _lastLocation = '';

  THDockTab _activeTab(String location) {
    if (location.startsWith('/jobs')) return THDockTab.jobs;
    if (location.startsWith('/messages') || location.startsWith('/chat')) {
      return THDockTab.chat;
    }
    if (location.startsWith('/profile') || location.startsWith('/settings')) {
      return THDockTab.profile;
    }
    return THDockTab.home;
  }

  void _go(THDockTab tab, bool isTradie) => switch (tab) {
    THDockTab.home => context.go(isTradie ? '/tradie' : '/home'),
    THDockTab.jobs => context.go('/jobs'),
    THDockTab.chat => context.go('/messages'),
    THDockTab.profile => context.go('/profile'),
  };

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileViewModelProvider);
    final location = GoRouterState.of(context).uri.path;
    final width = MediaQuery.sizeOf(context).width;
    final unread = ref.watch(chatUnreadProvider).valueOrNull ?? 0;

    // role == 1 → Tradie. Any other value (including null while loading) →
    // Homeowner nav, matching v1 MainLayout and getRoleRoute's fallback.
    final isTradie = profileState.profile?['role'] == 1;
    final useRail = width >= kThBreakpointLeftRail;

    // The shell rebuilds on every navigation — refresh the badge then, so
    // reading a thread clears its count without an app-lifecycle listener.
    if (location != _lastLocation) {
      _lastLocation = location;
      Future.microtask(() => ref.read(chatUnreadProvider.notifier).refresh());
    }

    final chrome = ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: useRail
          ? _ThNavRail(
              activeTab: _activeTab(location),
              isTradie: isTradie,
              unread: unread,
              onSelected: (tab) => _go(tab, isTradie),
              onNewRequest: () => context.push('/jobs/new'),
            )
          // The dock is full-bleed, opaque and pads itself by the
          // home-indicator inset, so it is not wrapped in a SafeArea.
          : THDock(
              role: isTradie ? THDockRole.tradie : THDockRole.homeowner,
              active: _activeTab(location),
              badges: {THDockTab.chat: unread},
              onSelected: (tab) => _go(tab, isTradie),
              onNewRequest: () => context.push('/jobs/new'),
            ),
    );

    // Keep the routed subtree under the app's FixoTheme. Several Phase 3
    // routes still render v1 screens, which require the Fixo THColors
    // extension; ThScope installs only the v2 extension.
    return useRail
        ? Scaffold(
            body: Row(
              children: [
                chrome,
                Expanded(child: widget.child),
              ],
            ),
          )
        : Column(
            children: [
              // Content ends where the bar begins (nothing renders behind it).
              Expanded(child: _aboveDock(context, widget.child)),
              chrome,
            ],
          );
  }

  /// The dock now owns the bottom home-indicator inset and the keyboard sits
  /// over it, so the routed content sees only what is left: no bottom
  /// padding/viewPadding (no double gap from a child SafeArea), and a keyboard
  /// inset reduced by the dock's height (the bar stays at the bottom edge,
  /// under the keyboard, instead of being pushed above it).
  Widget _aboveDock(BuildContext context, Widget child) {
    final mq = MediaQuery.of(context);
    final dockHeight =
        Sizes.dock + Radii.hairline + mq.viewPadding.bottom;
    return MediaQuery(
      data: mq.copyWith(
        padding: mq.padding.copyWith(bottom: 0),
        viewPadding: mq.viewPadding.copyWith(bottom: 0),
        viewInsets: mq.viewInsets.copyWith(
          bottom: (mq.viewInsets.bottom - dockHeight).clamp(
            0.0,
            double.infinity,
          ),
        ),
      ),
      child: child,
    );
  }
}

/// TH-token left rail for ≥[kThBreakpointLeftRail] widths. needs-design (D-4):
/// same structure as the v1 _FixoNavRail, v2 palette, no mockup exists yet.
class _ThNavRail extends StatelessWidget {
  final THDockTab activeTab;
  final bool isTradie;
  final int unread;
  final ValueChanged<THDockTab> onSelected;
  final VoidCallback onNewRequest;

  const _ThNavRail({
    required this.activeTab,
    required this.isTradie,
    required this.unread,
    required this.onSelected,
    required this.onNewRequest,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Container(
      width: kThRailWidth,
      decoration: BoxDecoration(
        color: c.paper,
        border: Border(right: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: Space.s4),
            // New-request action (homeowner only, like the dock FAB).
            if (!isTradie) ...[
              _RailPostJobButton(onTap: onNewRequest),
              const SizedBox(height: Space.s2),
              Divider(height: 1, color: c.line),
              const SizedBox(height: Space.s2),
            ],
            // Navigation items — same four tabs as the dock.
            for (final tab in THDockTab.values) ...[
              _RailItem(
                tab: tab,
                selected: tab == activeTab,
                unread: tab == THDockTab.chat ? unread : 0,
                onTap: () => onSelected(tab),
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
  final THDockTab tab;
  final bool selected;
  final int unread;
  final VoidCallback onTap;

  const _RailItem({
    required this.tab,
    required this.selected,
    required this.unread,
    required this.onTap,
  });

  static const _labels = {
    THDockTab.home: 'Home',
    THDockTab.jobs: 'Jobs',
    THDockTab.chat: 'Chat',
    THDockTab.profile: 'Profile',
  };
  static const _icons = {
    THDockTab.home: Icons.home_rounded,
    THDockTab.jobs: Icons.work_rounded,
    THDockTab.chat: Icons.chat_bubble_rounded,
    THDockTab.profile: Icons.person_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final color = selected ? c.textBrand : c.textSoft;
    return Semantics(
      label: unread > 0 ? '${_labels[tab]}, $unread unread' : _labels[tab],
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s2,
            vertical: Space.s2,
          ),
          child: SizedBox(
            width: Sizes.railItem,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(_icons[tab], size: Sizes.iconLg, color: color),
                    if (unread > 0)
                      Positioned(
                        top: -2,
                        right: -6,
                        child: Container(
                          width: Sizes.unreadDot,
                          height: Sizes.unreadDot,
                          decoration: BoxDecoration(
                            color: c.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  _labels[tab]!,
                  maxLines: 1,
                  style: THType.label.copyWith(
                    fontSize: THType.railLabel.fontSize,
                    letterSpacing: 0,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
    final c = context.th;
    // Same emphasis as the dock's Post job slot: gold rounded-square tile with
    // the hunt glyph, "Post job" label in accentText. The single gold action.
    return Semantics(
      button: true,
      label: 'New request',
      excludeSemantics: true,
      child: Tooltip(
        message: 'New request',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: SizedBox(
            width: Sizes.railItem,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Container(
                  width: Sizes.dockPost,
                  height: Sizes.dockPost,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: THHuntGlyph(
                    size: Sizes.dockPostGlyph,
                    color: c.onAccent,
                  ),
                ),
                Text(
                  'Post job',
                  maxLines: 1,
                  softWrap: false,
                  style: THType.label.copyWith(
                    fontSize: THType.railLabel.fontSize,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w500,
                    color: c.accentText,
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
