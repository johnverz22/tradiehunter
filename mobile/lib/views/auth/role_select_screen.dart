import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../widgets/auth_controls.dart';

class RoleSelectScreen extends ConsumerStatefulWidget {
  final String userId;

  /// P9-02: one-time token from GoogleLogin — required by
  /// PATCH /api/auth/complete-registration.
  final String registrationToken;

  const RoleSelectScreen({
    super.key,
    required this.userId,
    required this.registrationToken,
  });

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  int? _selectedRole;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final th = Theme.of(context).extension<THColors>()!;

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

    return PopScope(
      // Prevent back navigation — a stub account already exists on the backend.
      // The user must pick a role to complete sign-up.
      canPop: false,
      child: Scaffold(
        // ── Sticky CTA at bottom ─────────────────────────────────────────
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.s6, Space.s2, Space.s6, Space.s4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedRole == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.s2),
                    child: Text(
                      "Choose how you'll use TradieHunter",
                      key: const Key('role_helper'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: th.textSoft,
                      ),
                    ),
                  ),
                FixoPrimaryButton(
                  label: 'Continue',
                  isLoading: authState.isLoading,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s6, // 24
              vertical: Space.s8,   // 40
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Heading (left-aligned, per S08) ─────────────────────
                  Text(
                    'How will you use\nTradieHunter?',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: th.text,
                      fontWeight: FW.bold,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: Space.s8), // 40

                  if (authState.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s4),
                      child: Text(
                        authState.error!,
                        style: TextStyle(color: th.danger),
                      ),
                    ),

                  // ── Homeowner card ───────────────────────────────────────
                  AuthRoleChoice(
                    icon: Icons.home_rounded,
                    title: 'Homeowner',
                    description: 'Post jobs and hire local tradies',
                    selected: _selectedRole == 0,
                    onPressed: authState.isLoading
                        ? null
                        : () => setState(() => _selectedRole = 0),
                  ),

                  const SizedBox(height: Space.s4), // 16

                  // ── Tradie card ──────────────────────────────────────────
                  AuthRoleChoice(
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
    );
  }
}
