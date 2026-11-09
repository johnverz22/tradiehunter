import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/design_tokens.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../widgets/fixo_buttons.dart';
import 'widgets/auth_controls.dart';
import 'widgets/fixo_feedback.dart';


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
    final outcome = await ref
        .read(authViewModelProvider.notifier)
        .login(_emailController.text.trim(), _passwordController.text);
    if (!mounted || outcome == null) return;

    switch (outcome) {
      case AuthSignedIn():
        // Invalidate stale profile from any previous session and reload.
        ref.invalidate(profileViewModelProvider);
        final destination = await getRoleRoute(
          ref.read(sharedProfileRepositoryProvider),
        );
        if (mounted) context.go(destination);
      // P1-03: unverified account — the backend withheld the JWT.
      case AuthNeedsEmailVerification(:final email):
        context.go('/verify-email', extra: email);
    }
  }

  void _googleLogin() async {
    final result = await ref
        .read(authViewModelProvider.notifier)
        .loginWithGoogle();
    if (!mounted) return;

    switch (result) {
      case GoogleLoginSuccess():
        ref.invalidate(profileViewModelProvider);
        final destination = await getRoleRoute(
          ref.read(sharedProfileRepositoryProvider),
        );
        if (mounted) context.go(destination);
      case GoogleLoginRequiresRegistration(
        :final userId,
        :final registrationToken,
      ):
        context.go(
          '/role-select',
          extra: (userId: userId, registrationToken: registrationToken),
        );
      // P1-04: Google can't link an unverified password account.
      case GoogleLoginRequiresVerification(:final email):
        context.go('/verify-email', extra: email);
      case GoogleLoginCancelled():
        break;
    }
  }

  // No POST /api/auth/forgot-password exists on the backend (AuthController
  // has register/login/refresh/google only) — coming-soon placeholder.
  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset is not available in this app.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      key: const Key('login_screen'),
      body: SafeArea(
        child: AuthScrollView(
          padding: const EdgeInsets.fromLTRB(Space.s6, 48, Space.s6, Space.s6),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FixoWordmark(fontSize: DesignTokens.fontSizeDisplay),
                const SizedBox(height: Space.s7),
                Text(
                  'Welcome back',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FW.bold,
                  ),
                ),
                const SizedBox(height: Space.s7),
                if (authState.error != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Space.s4),
                      child: FixoInfoBanner.error(message: authState.error!),
                    ),
                  ),
                TextFormField(
                  key: const Key('email_field'),
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'e.g. kiaora@example.co.nz',
                  ),
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
                const SizedBox(height: Space.s4),
                TextFormField(
                  key: const Key('password_field'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: Space.s1),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: Space.s4),
                FixoPrimaryButton(
                  key: const Key('login_button'),
                  label: 'Sign in',
                  isLoading: authState.isLoading,
                  onPressed: _login,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.s6),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s4),
                        child: Text(
                          'or',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
                AuthGoogleButton(
                  icon: const _GoogleG(),
                  onPressed: authState.isLoading ? null : _googleLogin,
                ),
                const SizedBox(height: Space.s7),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      child: const Text('Create account'),
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
        fontSize: DesignTokens.fontSizeH2Small,
        fontWeight: FW.bold,
        color: SocialColors.googleBlue,
      ),
    );
  }
}

