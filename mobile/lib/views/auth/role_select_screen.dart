import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';

class RoleSelectScreen extends ConsumerWidget {
  final String userId;

  const RoleSelectScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authViewModelProvider);
    final theme = Theme.of(context);

    Future<void> pickRole(int role) async {
      final success = await ref
          .read(authViewModelProvider.notifier)
          .completeRegistration(userId, role);
      if (success && context.mounted) {
        // UserRole: Homeowner=0, Tradie=1.
        ref.invalidate(profileViewModelProvider);
        context.go(role == 1 ? '/tradie' : '/home');
      }
    }

    return PopScope(
      // Prevent back navigation — a stub account already exists on the backend.
      // The user must pick a role to complete sign-up.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                Text(
                  'One last step',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'How will you be using Fixo?',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                if (authState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      authState.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // ── Homeowner card ────────────────────────────────────────
                _RoleCard(
                  icon: Icons.home_rounded,
                  title: 'Homeowner',
                  subtitle: 'I need to find and hire trusted tradies.',
                  isLoading: authState.isLoading,
                  onTap: () => pickRole(0),
                ),

                const SizedBox(height: 16),

                // ── Tradie card ───────────────────────────────────────────
                _RoleCard(
                  icon: Icons.handyman_rounded,
                  title: 'Tradie',
                  subtitle: 'I\'m a professional looking for qualified leads.',
                  isLoading: authState.isLoading,
                  onTap: () => pickRole(1),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: DesignTokens.amber.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radius),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: DesignTokens.amberDark,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
