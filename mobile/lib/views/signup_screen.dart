import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/design_tokens.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/locale_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../widgets/fixo_buttons.dart';
import 'widgets/auth_controls.dart';
import 'widgets/fixo_feedback.dart';

/// S06: wordmark → "Create your account" → role toggle → fields → CTA.
/// Register API takes firstName/lastName separately; the "Full name" field
/// is split on the first space before submitting.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
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
    final th = Theme.of(context).extension<THColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      key: const Key('signup_screen'),
      // ── Sticky CTA ────────────────────────────────────────────────────────
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.s6,
              Space.s2,
              Space.s6,
              Space.s4,
            ),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: FixoPrimaryButton(
                  key: const Key('signup_button'),
                  label: 'Create account',
                  isLoading: authState.isLoading,
                  onPressed: _signup,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: AuthScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.s6,
            Space.s8,
            Space.s6,
            Space.s8,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Wordmark ───────────────────────────────────────────────
                const FixoWordmark(fontSize: DesignTokens.fontSizeDisplay),
                const SizedBox(height: Space.s7), // 32
                // ── Heading ────────────────────────────────────────────────
                Text(
                  'Create your account',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FW.bold,
                    color: th.text,
                  ),
                ),
                const SizedBox(height: Space.s1), // 4
                Text(
                  'I\'m signing up as a...',
                  style: textTheme.bodyMedium?.copyWith(color: th.textSoft),
                ),
                const SizedBox(height: Space.s4), // 16
                // ── Role toggle ────────────────────────────────────────────
                _RoleToggle(
                  selectedRole: _selectedRole,
                  onRoleChanged: (r) => setState(() => _selectedRole = r),
                ),
                const SizedBox(height: Space.s6), // 24
                // ── Error banner ───────────────────────────────────────────
                if (authState.error != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Space.s4),
                      child: FixoInfoBanner.error(message: authState.error!),
                    ),
                  ),

                // ── Full name ──────────────────────────────────────────────
                TextFormField(
                  key: const Key('full_name_field'),
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    hintText: 'e.g. Sarah Mitchell',
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: Space.s4),

                // ── Email ──────────────────────────────────────────────────
                TextFormField(
                  key: const Key('signup_email_field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'e.g. kiaora@example.co.nz',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return 'Please enter your email';
                    if (!v.contains('@')) return 'Please enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: Space.s4),

                // ── Password ───────────────────────────────────────────────
                TextFormField(
                  key: const Key('signup_password_field'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _signup(),
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
                PasswordRules(password: _passwordController.text),
                const SizedBox(height: Space.s4), // 16
                // ── Terms line ─────────────────────────────────────────────
                _TermsLine(
                  style: textTheme.bodySmall?.copyWith(color: th.textSoft),
                  linkColor: th.brand,
                ),

                const SizedBox(height: Space.s6), // 24
                // ── Google divider + button ────────────────────────────────
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s4),
                      child: Text(
                        'or',
                        style: textTheme.bodySmall?.copyWith(
                          color: th.textSoft,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: Space.s4),
                AuthGoogleButton(
                  icon: const _GoogleG(),
                  onPressed: authState.isLoading ? null : _googleSignup,
                ),

                const SizedBox(height: Space.s7), // 32
                // ── Footer ─────────────────────────────────────────────────
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: textTheme.bodyMedium?.copyWith(color: th.textSoft),
                    ),
                    TextButton(
                      onPressed: () => context.go('/auth'),
                      child: const Text('Log in'),
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

// ── Terms ─────────────────────────────────────────────────────────────────────
//
// Links are only tappable when the backend supplies the URL
// (GET /api/config/locale); otherwise it is plain text — no invented
// destination.

class _TermsLine extends ConsumerWidget {
  final TextStyle? style;
  final Color linkColor;
  const _TermsLine({required this.style, required this.linkColor});

  static String? _url(Map<String, dynamic>? config, String key) {
    final value = (config?['locale'] as Map?)?[key] ?? config?[key];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(localeConfigProvider).valueOrNull;
    final terms = _url(config, 'termsOfServiceUrl');
    final privacy = _url(config, 'privacyPolicyUrl');

    Widget link(String label, String? url) => url == null
        ? Text(label, style: style)
        : TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(Sizes.tapMin, Sizes.tapMin),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: linkColor,
              textStyle: style?.copyWith(
                decoration: TextDecoration.underline,
                fontWeight: FW.semibold,
              ),
            ),
            onPressed: () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: Text(label),
          );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('By continuing you agree to our ', style: style),
        link('Terms', terms),
        Text(' and ', style: style),
        link('Privacy Policy', privacy),
        Text('.', style: style),
      ],
    );
  }
}

// ── Role toggle ───────────────────────────────────────────────────────────────
//
// 2-column segmented picker. Selected tab: brand border (navy/blue300) +
// surface fill + card shadow. Unselected: transparent, muted icon/text.

class _RoleToggle extends StatelessWidget {
  final int selectedRole;
  final ValueChanged<int> onRoleChanged;

  const _RoleToggle({required this.selectedRole, required this.onRoleChanged});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(minHeight: Sizes.segmentMin),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: Alpha.overlay)
            : th.line.withValues(alpha: Alpha.borderMid),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      padding: const EdgeInsets.all(Space.s1),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _RoleTab(
                key: const Key('role_homeowner'),
                label: 'Homeowner',
                icon: Icons.home_rounded,
                selected: selectedRole == 0,
                onTap: () => onRoleChanged(0),
              ),
            ),
            Expanded(
              child: _RoleTab(
                key: const Key('role_tradie'),
                label: 'Tradie',
                icon: Icons.handyman_rounded,
                selected: selectedRole == 1,
                onTap: () => onRoleChanged(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTab({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: FixoDurations.fast,
          padding: const EdgeInsets.symmetric(vertical: Space.s3),
          decoration: BoxDecoration(
            color: selected ? th.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.card - 2),
            border: selected ? Border.all(color: th.brand, width: 2) : null,
            boxShadow: selected ? DesignTokens.cardShadow(isDark) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: Sizes.iconMd,
                color: selected ? th.brand : th.textSoft,
              ),
              const SizedBox(height: Space.s1),
              Text(
                label,
                style: TextStyle(
                  fontFamily: DesignTokens.fontBody,
                  fontSize: DesignTokens.fontSizeSecondary,
                  fontWeight: selected ? FW.bold : FW.medium,
                  color: selected ? th.text : th.textSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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
