import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/design_tokens.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../widgets/fixo_buttons.dart';

/// Mockup 03-login: wordmark + "Welcome back", labeled 48h inputs,
/// amber Sign in, "or continue with" divider, Google button, footer link.
/// Auth wiring (email/password + Google + error state) is unchanged.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authViewModelProvider.notifier).clearError();
    final success = await ref.read(authViewModelProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );
    if (success && mounted) {
      // Invalidate stale profile from any previous session and reload.
      ref.invalidate(profileViewModelProvider);
      final destination = await getRoleRoute(
        ref.read(sharedProfileRepositoryProvider),
      );
      if (mounted) context.go(destination);
    }
  }

  void _googleLogin() async {
    final result =
        await ref.read(authViewModelProvider.notifier).loginWithGoogle();
    if (!mounted) return;

    switch (result) {
      case GoogleLoginSuccess():
        ref.invalidate(profileViewModelProvider);
        final destination = await getRoleRoute(
          ref.read(sharedProfileRepositoryProvider),
        );
        if (mounted) context.go(destination);
      case GoogleLoginRequiresRegistration(:final userId):
        context.go('/role-select', extra: userId);
      case GoogleLoginCancelled():
        break;
    }
  }

  // TODO(backend): wire to POST /api/auth/forgot-password.
  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset — coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FixoWordmark(fontSize: 32),
                const SizedBox(height: 32),
                Text(
                  'Welcome back',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 32),
                if (authState.error != null)
                  _ErrorBanner(message: authState.error!),
                const Text('Email',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                      hintText: 'e.g. kiaora@example.co.nz'),
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
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Password',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    GestureDetector(
                      onTap: _forgotPassword,
                      child: Semantics(
                        button: true,
                        label: 'Forgot password',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          child: Text('Forgot password?',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: DesignTokens.brand500)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _login(),
                  decoration: InputDecoration(
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
                    if (v == null || v.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FixoPrimaryButton(
                  label: 'Sign in',
                  isLoading: authState.isLoading,
                  onPressed: _login,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('or continue with',
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
                    onPressed:
                        authState.isLoading ? null : _googleLogin,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GoogleG(),
                        SizedBox(width: 12),
                        Text('Google',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ",
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7))),
                    GestureDetector(
                      onTap: () => context.go('/signup'),
                      child: Semantics(
                        button: true,
                        label: 'Create account',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          child: Text('Create account',
                              style: TextStyle(
                                  color: DesignTokens.brand500,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
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
}

/// Minimal multicolor "G" mark — avoids image assets while looking
/// closer to the Google brand than a blue circle with a letter.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4285F4),
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
