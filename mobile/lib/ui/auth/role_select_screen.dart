// ThRoleSelectScreen: v2 post-Google role picker (migration plan 3.2,
// id `role_select`).
//
// Hand-owned port of views/auth/role_select_screen.dart — same props
// (userId + P9-02 one-time registrationToken), same PopScope(no back), same
// disabled-until-selected Continue, same routing (role 1 → /tradie/onboarding,
// role 0 → /home), same keys and card semantics. The gallery stub's "You can
// switch later in settings." copy is deliberately NOT used — tests assert it
// never appears (the backend does not support switching yet).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';

class ThRoleSelectScreen extends ConsumerStatefulWidget {
  final String userId;

  /// P9-02: one-time token from GoogleLogin — required by
  /// PATCH /api/auth/complete-registration.
  final String registrationToken;

  const ThRoleSelectScreen({
    super.key,
    required this.userId,
    required this.registrationToken,
  });

  @override
  ConsumerState<ThRoleSelectScreen> createState() => _ThRoleSelectScreenState();
}

class _ThRoleSelectScreenState extends ConsumerState<ThRoleSelectScreen> {
  int? _selectedRole;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);

    Future<void> pickRole(int role) async {
      final success = await ref
          .read(authViewModelProvider.notifier)
          .completeRegistration(widget.userId, widget.registrationToken, role);
      if (success && context.mounted) {
        // UserRole: Homeowner=0, Tradie=1.
        ref.invalidate(profileViewModelProvider);
        // New tradies go straight into the P1-09 onboarding wizard — without
        // a trade, a geo point, a schedule and a verified credential they can
        // never be matched, so the dashboard would be a dead end.
        context.go(role == 1 ? '/tradie/onboarding' : '/home');
      }
    }

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          final c = context.th;
          return PopScope(
            // Prevent back navigation — a stub account already exists on the
            // backend. The user must pick a role to complete sign-up.
            canPop: false,
            child: Scaffold(
              backgroundColor: c.paper,
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.s6,
                    Space.s2,
                    Space.s6,
                    Space.s4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: Space.s2,
                    children: [
                      if (_selectedRole == null)
                        Text(
                          "Choose how you'll use TradieHunter",
                          key: const Key('role_helper'),
                          textAlign: TextAlign.center,
                          style: THType.meta.copyWith(color: c.textSoft),
                        ),
                      THButton(
                        label: 'Continue',
                        loading: authState.isLoading,
                        onPressed: _selectedRole == null
                            ? null
                            : () => pickRole(_selectedRole!),
                      ),
                    ],
                  ),
                ),
              ),
              body: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 480, // one-off: v1 auth form width
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.s6,
                        vertical: Space.s8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Heading (left-aligned, per S08)
                          Text(
                            'How will you use\nTradieHunter?',
                            style: THType.h1.copyWith(
                              color: c.text,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: Space.s8),
                          if (authState.error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Space.s4),
                              child: Text(
                                authState.error!,
                                style: THType.body.copyWith(color: c.danger),
                              ),
                            ),
                          _ThRoleChoice(
                            icon: Icons.home_rounded,
                            title: 'Homeowner',
                            description: 'Post jobs and hire local tradies',
                            selected: _selectedRole == 0,
                            onPressed: authState.isLoading
                                ? null
                                : () => setState(() => _selectedRole = 0),
                          ),
                          const SizedBox(height: Space.s4),
                          _ThRoleChoice(
                            icon: Icons.handyman_rounded,
                            title: 'Tradie',
                            description: 'Find work and grow your business',
                            selected: _selectedRole == 1,
                            onPressed: authState.isLoading
                                ? null
                                : () => setState(() => _selectedRole = 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Role choice card — carries the v1 semantics contract:
/// `Semantics(selected, inMutuallyExclusiveGroup, button, label: '$title: $description')`
/// and the `ValueKey('checked') / ValueKey('unchecked')` radio indicator.
class _ThRoleChoice extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  const _ThRoleChoice({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: '$title: $description',
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: THDurations.fast,
          decoration: BoxDecoration(
            color: selected ? c.tintBrand : c.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              color: selected ? c.brand : c.line,
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(Space.s4),
          child: Row(
            spacing: Space.s3,
            children: [
              Container(
                width: Sizes.tapMin,
                height: Sizes.tapMin,
                decoration: BoxDecoration(
                  color: selected
                      ? c.brand.withValues(alpha: 0.12)
                      : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: selected ? c.brand : c.textSoft,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Space.s1,
                  children: [
                    Text(
                      title,
                      style: THType.title.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      description,
                      style: THType.meta.copyWith(color: c.textSoft),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: THDurations.fast,
                child: selected
                    ? Container(
                        key: const ValueKey('checked'),
                        width: Space.s6,
                        height: Space.s6,
                        decoration: BoxDecoration(
                          color: c.brand,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: Sizes.icon,
                          color: c.onBrand,
                        ),
                      )
                    : Container(
                        key: const ValueKey('unchecked'),
                        width: Space.s6,
                        height: Space.s6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c.line, width: 1.5),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
