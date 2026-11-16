// Shared building blocks for the v2 auth screens (migration plan 3.2).
//
// Hand-owned v2 replacements for views/widgets/auth_controls.dart, which
// lib/ui/** may not import. Copy and tokens only — behaviour is identical:
// same AutofillGroup/errorMaxLines wrapper, same Google button copy, same
// password-rule semantics, same terms-line truthfulness.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../../viewmodels/locale_viewmodel.dart';

/// Scroll + autofill wrapper for auth forms. Mirrors v1 `AuthScrollView`:
/// maxWidth 480, AutofillGroup, errorMaxLines 4 (labels render above the
/// fields in v2, so the floating-label override is not needed).
class ThAuthScroll extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ThAuthScroll({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: Space.s6),
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: padding,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480), // one-off: v1 auth
        child: AutofillGroup(child: child),
      ),
    ),
  );
}

/// Inline error banner for auth state errors. v1 used FixoInfoBanner.error
/// wrapped in a liveRegion — the liveRegion is part of the a11y contract.
class ThAuthErrorBanner extends StatelessWidget {
  final String message;

  const ThAuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.s3),
        decoration: BoxDecoration(
          color: c.dangerTint,
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: c.danger, width: 1.5),
        ),
        child: Row(
          spacing: Space.s2_5,
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: c.danger),
            Expanded(
              child: Text(
                message,
                style: THType.meta.copyWith(color: c.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Continue with Google" — v2 secondary THButton. Tests tap
/// `find.text('Continue with Google')` (label preserved from v1).
class ThGoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const ThGoogleButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) => THButton(
    label: 'Continue with Google',
    kind: THButtonKind.secondary,
    icon: Icons.public_rounded,
    onPressed: onPressed,
  );
}

/// Password live checklist. Semantics labels are contractual:
/// `Met: <rule>` / `Not met: <rule>` (asserted by the auth tests).
class ThPasswordRules extends StatelessWidget {
  final String password;

  const ThPasswordRules({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final rules = <String, bool>{
      'At least 8 characters': password.length >= 8,
      'An uppercase letter': password.contains(RegExp(r'[A-Z]')),
      'A lowercase letter': password.contains(RegExp(r'[a-z]')),
      'A number': password.contains(RegExp(r'[0-9]')),
      'A symbol': password.contains(RegExp(r'[^A-Za-z0-9]')),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rules.entries
          .map(
            (rule) => Semantics(
              label: '${rule.value ? 'Met' : 'Not met'}: ${rule.key}',
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.s1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Space.s2,
                    children: [
                      Icon(
                        rule.value
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        size: Sizes.icon,
                        color: rule.value ? c.success : c.textSoft,
                      ),
                      Expanded(
                        child: Text(
                          rule.key,
                          style: THType.body.copyWith(color: c.textSoft),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

/// Homeowner / Tradie segmented picker for signup. Keys
/// `role_homeowner` / `role_tradie` and the `Semantics(button, selected,
/// label)` contract carry over from v1.
class ThRoleToggle extends StatelessWidget {
  final int selectedRole;
  final ValueChanged<int> onRoleChanged;

  const ThRoleToggle({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    Widget tab({
      required Key key,
      required String label,
      required IconData icon,
      required int role,
    }) {
      final selected = selectedRole == role;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          onTap: () => onRoleChanged(role),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onRoleChanged(role),
            child: AnimatedContainer(
              duration: THDurations.fast,
              padding: const EdgeInsets.symmetric(vertical: Space.s3),
              decoration: BoxDecoration(
                color: selected ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.control),
                border: selected
                    ? Border.all(color: c.brand, width: 2)
                    : Border.all(color: Colors.transparent),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: Space.s1,
                children: [
                  Icon(
                    icon,
                    size: Sizes.iconLg,
                    color: selected ? c.brand : c.textSoft,
                  ),
                  Text(
                    label,
                    style: THType.button.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? c.text : c.textSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      padding: const EdgeInsets.all(Space.s1),
      // IntrinsicHeight: the stretch row would force an infinite height
      // inside the scrollable auth forms (same reason v1 wraps it).
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tab(
              key: const Key('role_homeowner'),
              label: 'Homeowner',
              icon: Icons.home_rounded,
              role: 0,
            ),
            tab(
              key: const Key('role_tradie'),
              label: 'Tradie',
              icon: Icons.handyman_rounded,
              role: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Terms line. Links are only tappable when the backend supplies the URL
/// (GET /api/config/locale); otherwise plain text — no invented destination.
class ThTermsLine extends ConsumerWidget {
  const ThTermsLine({super.key});

  static String? _url(Map<String, dynamic>? config, String key) {
    final value = (config?['locale'] as Map?)?[key] ?? config?[key];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.th;
    final config = ref.watch(localeConfigProvider).valueOrNull;
    final terms = _url(config, 'termsOfServiceUrl');
    final privacy = _url(config, 'privacyPolicyUrl');
    final style = THType.meta.copyWith(color: c.textSoft);

    Widget link(String label, String? url) => url == null
        ? Text(label, style: style)
        : TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(Sizes.tapMin, Sizes.tapMin),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: c.textBrand,
              textStyle: style.copyWith(
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
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
