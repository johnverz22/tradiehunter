// ThShell: the v2 navigation shell (migration plan 3.1).
//
// Mirrors views/main_layout.dart exactly at the behavioural level:
//   • role from profileViewModelProvider (`profile['role'] == 1` → tradie)
//   • prefix-based active-tab detection (/jobs*, /messages*|/chat*, /profile*|/settings*)
//   • role-dependent landing route (tab 0 → /tradie or /home)
//   • homeowner-only centre action → context.push('/jobs/new')
//   • wide layout (≥1024): left rail replica in TH tokens
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

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: useRail
          ? Scaffold(
              body: Row(
                children: [
                  _ThNavRail(
                    activeTab: _activeTab(location),
                    isTradie: isTradie,
                    unread: unread,
                    onSelected: (tab) => _go(tab, isTradie),
                    onNewRequest: () => context.push('/jobs/new'),
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            )
          : Stack(
              children: [
                Positioned.fill(child: widget.child),
                Positioned(
                  left: Space.s3_5,
                  right: Space.s3_5,
                  bottom: Space.s4,
                  // The floating dock sits outside any Scaffold — the v1
                  // bottom bar got its Material from Scaffold. THDock's
                  // InkWells need one, so provide a transparent Material.
                  child: Material(
                    type: MaterialType.transparency,
                    child: SafeArea(
                      top: false,
                      child: THDock(
                        role: isTradie
                            ? THDockRole.tradie
                            : THDockRole.homeowner,
                        active: _activeTab(location),
                        badges: {THDockTab.chat: unread},
                        onSelected: (tab) => _go(tab, isTradie),
                        onNewRequest: () => context.push('/jobs/new'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
            width: 56, // one-off: dock/rail item width
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
                          width: 9,
                          height: 9,
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
                    fontSize: 10.5,
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
    return Semantics(
      button: true,
      label: 'New request',
      child: Tooltip(
        message: 'New request',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.sheet),
          child: Container(
            width: 48, // one-off: rail action size (v1 _RailPostJobButton)
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accent,
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: THHuntGlyph(size: 24, color: c.onAccent),
          ),
        ),
      ),
    );
  }
}
