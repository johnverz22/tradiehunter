// ThSignUpScreen: v2 signup (migration plan 3.2, id `signup` — no v2 mockup,
// composed from sign_in + THField per D-4).
//
// Hand-owned port of views/signup_screen.dart — same providers, same keys
// (signup_screen / signup_button / full_name_field / signup_email_field /
// signup_password_field / role_homeowner / role_tradie), same validators
// ('Required', password rules), same name-split, same sticky-CTA-over-
// keyboard behaviour, same routing for every outcome.
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

class ThSignUpScreen extends ConsumerStatefulWidget {
  const ThSignUpScreen({super.key});

  @override
  ConsumerState<ThSignUpScreen> createState() => _ThSignUpScreenState();
}

class _ThSignUpScreenState extends ConsumerState<ThSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  int _selectedRole = 0; // 0=Homeowner, 1=Tradie
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Splits "Sarah Mitchell" → ("Sarah", "Mitchell").
  /// Single-word names become (word, "").
  (String, String) _splitName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts[0], '');
    return (parts.first, parts.sublist(1).join(' '));
  }

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authViewModelProvider.notifier).clearError();

    final (firstName, lastName) = _splitName(_fullNameController.text);
    final outcome = await ref
        .read(authViewModelProvider.notifier)
        .register(
          firstName,
          lastName,
          _emailController.text.trim(),
          _passwordController.text,
          _selectedRole,
        );
    if (!mounted || outcome == null) return;

    switch (outcome) {
      // P1-03: registration emails an OTP — no JWT issued here.
      case AuthNeedsEmailVerification(:final email):
        context.go('/verify-email', extra: email);
      case AuthSignedIn():
        ref.invalidate(profileViewModelProvider);
        final destination = await getRoleRoute(
          ref.read(sharedProfileRepositoryProvider),
        );
        if (mounted) context.go(destination);
    }
  }

  void _googleSignup() async {
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
      case GoogleLoginRequiresVerification(:final email):
        context.go('/verify-email', extra: email);
      case GoogleLoginCancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) => Scaffold(
          key: const Key('signup_screen'),
          backgroundColor: context.th.paper,
          // ── Sticky CTA — padded by the keyboard inset like v1 (Scaffold
          // does not lift bottomNavigationBar over the keyboard), so the
          // button always stays visible above it.
          bottomNavigationBar: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Sizes.gutter,
                  Space.s2,
                  Sizes.gutter,
                  Space.s4,
                ),
                child: THButton(
                  key: const Key('signup_button'),
                  label: 'Create account',
                  loading: authState.isLoading,
                  onPressed: _signup,
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: ThAuthScroll(
              padding: const EdgeInsets.fromLTRB(
                Sizes.gutter,
                Space.s8,
                Sizes.gutter,
                Space.s6,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    THWordmark(),
                    const SizedBox(height: Space.s7),
                    Text(
                      'Create your account',
                      style: THType.h1.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.th.text,
                      ),
                    ),
                    const SizedBox(height: Space.s1),
                    Text(
                      "I'm signing up as a...",
                      style: THType.body.copyWith(color: context.th.textSoft),
                    ),
                    const SizedBox(height: Space.s4),
                    ThRoleToggle(
                      selectedRole: _selectedRole,
                      onRoleChanged: (r) => setState(() => _selectedRole = r),
                    ),
                    const SizedBox(height: Space.s6),
                    if (authState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.s4),
                        child: ThAuthErrorBanner(message: authState.error!),
                      ),
                    THTextField(
                      key: const Key('full_name_field'),
                      label: 'Full name',
                      hint: 'e.g. Sarah Mitchell',
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        return null;
                      },
                    ),
                    const SizedBox(height: Space.s4),
                    THTextField(
                      key: const Key('signup_email_field'),
                      label: 'Email',
                      hint: 'e.g. kiaora@example.co.nz',
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
                    const SizedBox(height: Space.s4),
                    THTextField(
                      key: const Key('signup_password_field'),
                      label: 'Password',
                      controller: _passwordController,
                      obscure: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) => _signup(),
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
                        if (v == null || v.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        if (!v.contains(RegExp(r'[A-Z]'))) {
                          return 'Must contain an uppercase letter';
                        }
                        if (!v.contains(RegExp(r'[a-z]'))) {
                          return 'Must contain a lowercase letter';
                        }
                        if (!v.contains(RegExp(r'[0-9]'))) {
                          return 'Must contain a number';
                        }
                        if (!v.contains(RegExp(r'[^A-Za-z0-9]'))) {
                          return 'Must contain a special character';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: Space.s2),
                    ThPasswordRules(password: _passwordController.text),
                    const SizedBox(height: Space.s4),
                    const ThTermsLine(),
                    const SizedBox(height: Space.s6),
                    THDivider(label: 'or'),
                    const SizedBox(height: Space.s4),
                    ThGoogleButton(
                      onPressed: authState.isLoading ? null : _googleSignup,
                    ),
                    const SizedBox(height: Space.s7),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Space.s2,
                      children: [
                        Text(
                          'Already have an account?',
                          style: THType.body.copyWith(
                            color: context.th.textSoft,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/auth'),
                          child: Text(
                            'Log in',
                            style: THType.button.copyWith(
                              color: context.th.textBrand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.s6),
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
