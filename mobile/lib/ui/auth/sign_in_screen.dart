// ThSignInScreen: v2 sign-in (migration plan 3.2, id `sign_in`).
//
// Hand-owned port of views/login_screen.dart — same providers, same keys
// (login_screen / email_field / password_field / login_button), same
// validators and copy, same login + Google outcome routing. Presentation is
// rebuilt from TH components per the mockup (wordmark, welcome header,
// fields, amber sign-in CTA, divider, Google button, footer link).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_common.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../feedback/th_notice.dart';

/// Mockup spacer between the wordmark and the heading (sign_in, 28px).
const double _kAfterWordmark = 28.0;

class ThSignInScreen extends ConsumerStatefulWidget {
  const ThSignInScreen({super.key});

  @override
  ConsumerState<ThSignInScreen> createState() => _ThSignInScreenState();
}

class _ThSignInScreenState extends ConsumerState<ThSignInScreen> {
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

  // No POST /api/auth/forgot-password exists on the backend — coming-soon
  // placeholder, same as v1.
  void _forgotPassword() {
    THNotice.info(context, NoticeCopy.stubUnavailable('Password reset'));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) => Scaffold(
          key: const Key('login_screen'),
          backgroundColor: context.th.paper,
          body: SafeArea(
            child: ThAuthScroll(
              padding: const EdgeInsets.fromLTRB(
                Sizes.gutter,
                Space.s7,
                Sizes.gutter,
                Space.s6,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: Space.s3,
                  children: [
                    THWordmark(),
                    // Mockup spacers (12 column gap + 28 / 4 / 20 spacer divs).
                    const SizedBox(height: _kAfterWordmark),
                    Semantics(
                      header: true,
                      child: Text(
                        'Welcome back',
                        style: THType.h1.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.th.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.s1),
                    Text(
                      'Sign in to manage your jobs.',
                      style: THType.body.copyWith(color: context.th.textSoft),
                    ),
                    const SizedBox(height: Space.s5),
                    if (authState.error != null)
                      ThAuthErrorBanner(message: authState.error!),
                    THTextField(
                      key: const Key('email_field'),
                      label: 'Email',
                      hint: 'e.g. kiaora@example.co.nz',
                      controller: _emailController,
                      icon: Icons.mail_outline_rounded,
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
                    THTextField(
                      key: const Key('password_field'),
                      label: 'Password',
                      controller: _passwordController,
                      obscure: _obscurePassword,
                      icon: Icons.lock_outline_rounded,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _login(),
                      trailing: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: Sizes.buttonSm,
                          height: Sizes.buttonSm,
                        ),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(Sizes.tapMin, Sizes.tapMin),
                          // Flush with the field edge like the mockup.
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerRight,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: THType.button.copyWith(
                            color: context.th.textBrand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    THButton(
                      key: const Key('login_button'),
                      label: 'Sign in',
                      loading: authState.isLoading,
                      onPressed: _login,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.s2),
                      child: THDivider(label: 'or'),
                    ),
                    ThGoogleButton(
                      onPressed: authState.isLoading ? null : _googleLogin,
                    ),
                    const SizedBox(height: Space.s3),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Space.s2,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: THType.body.copyWith(
                            color: context.th.textSoft,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/signup'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(Sizes.tapMin, Sizes.tapMin),
                          ),
                          child: Text(
                            'Create account',
                            style: THType.button.copyWith(
                              color: context.th.textBrand,
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }
}
