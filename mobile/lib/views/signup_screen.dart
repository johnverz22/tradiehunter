import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/design_tokens.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../widgets/fixo_buttons.dart';

/// Mockup 04-signup: back + "Join Fixo.", 2-col role selector
/// (selected = amber border + tint), labeled inputs, amber CTA,
/// Google button, footer Log in. Register wiring unchanged.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  int _selectedRole = 0; // 0 = Homeowner, 1 = Tradie  (matches UserRole enum)
  bool _obscurePassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authViewModelProvider.notifier).clearError();
    final success = await ref.read(authViewModelProvider.notifier).register(
          _firstNameController.text.trim(),
          _lastNameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
          _selectedRole,
        );
    if (success && mounted) {
      ref.invalidate(profileViewModelProvider);
      final destination = await getRoleRoute(
        ref.read(sharedProfileRepositoryProvider),
      );
      if (mounted) context.go(destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.go('/auth'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                Text(
                  'Join Fixo.',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        label: "I'm a\nHomeowner",
                        icon: Icons.home_rounded,
                        selected: _selectedRole == 0,
                        onTap: () => setState(() => _selectedRole = 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RoleCard(
                        label: "I'm a\nTradie",
                        icon: Icons.handyman_rounded,
                        selected: _selectedRole == 1,
                        onTap: () => setState(() => _selectedRole = 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (authState.error != null)
                  _ErrorBanner(message: authState.error!),
                _label('Full Name'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                            hintText: 'First'),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.givenName],
                        validator: (v) => v == null || v.isEmpty
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration:
                            const InputDecoration(hintText: 'Last'),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.familyName],
                        validator: (v) => v == null || v.isEmpty
                            ? 'Required'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _label('Email'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!v.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _label('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) => _signup(),
                  decoration: InputDecoration(
                    helperText: 'Min 8 chars, uppercase, number & symbol',
                    helperMaxLines: 1,
                    suffixIcon: IconButton(
                      tooltip:
                          _obscurePassword ? 'Show password' : 'Hide password',
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (!v.contains(RegExp(r'[A-Z]'))) {
                      return 'Password must contain an uppercase letter';
                    }
                    if (!v.contains(RegExp(r'[a-z]'))) {
                      return 'Password must contain a lowercase letter';
                    }
                    if (!v.contains(RegExp(r'[0-9]'))) {
                      return 'Password must contain a number';
                    }
                    if (!v.contains(RegExp(r'[^A-Za-z0-9]'))) {
                      return 'Password must contain a special character';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FixoPrimaryButton(
                  label: 'Create account',
                  isLoading: authState.isLoading,
                  onPressed: _signup,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('or sign up with',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    // TODO(backend): Google sign-up via POST /api/auth/google-oauth.
                    onPressed: authState.isLoading
                        ? null
                        : () => context.go('/auth'),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: Color(0xFF4285F4),
                          child: Text('G',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                        SizedBox(width: 12),
                        Text('Google',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7))),
                    GestureDetector(
                      onTap: () => context.go('/auth'),
                      child: Text('Log in',
                          style: TextStyle(
                              color: DesignTokens.brand500,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500));
}

class _RoleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? DesignTokens.amber.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? DesignTokens.amber
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
          borderRadius:
              BorderRadius.circular(DesignTokens.radius),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 28,
                color: selected
                    ? DesignTokens.amberDark
                    : Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(DesignTokens.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 18, color: colorScheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
