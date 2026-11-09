import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../theme/design_tokens.dart';

class AuthScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AuthScrollView({super.key, required this.child, required this.padding});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: padding,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: Theme.of(context).inputDecorationTheme
                .copyWith(
                  errorMaxLines: 4,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
          ),
          child: AutofillGroup(child: child),
        ),
      ),
    ),
  );
}

class AuthGoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  const AuthGoogleButton({super.key, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 56),
      padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s4),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          ExcludeSemantics(child: icon!),
          const SizedBox(width: Space.s3),
        ],
        const Flexible(
          child: Text('Continue with Google', textAlign: TextAlign.center),
        ),
      ],
    ),
  );
}

class AuthRoleChoice extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  const AuthRoleChoice({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Selected state: brand-coloured 2px border + brand tint background.
    // Unselected state: standard card border, card surface.
    final borderColor = selected ? th.brand : DesignTokens.borderCard(isDark);
    final bgColor     = selected ? th.tintBrand : th.surface;

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: '$title: $description',
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: FixoDurations.fast,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1,
            ),
            boxShadow: DesignTokens.cardShadow(isDark),
          ),
          padding: const EdgeInsets.all(Space.s4), // 16
          child: Row(
            children: [
              // ── Icon square ──────────────────────────────────────────────
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? th.brand.withValues(alpha: Alpha.tintAccent)
                      : (isDark
                          ? Colors.white.withValues(alpha: Alpha.tint)
                          : DesignTokens.surfaceDisabled(false)),
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: selected ? th.brand : th.textSoft,
                ),
              ),

              const SizedBox(width: Space.s3), // 12

              // ── Title + subtitle ─────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: th.text,
                        fontWeight: FW.semibold,
                      ),
                    ),
                    const SizedBox(height: Space.s0_5),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: th.textSoft,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: Space.s3), // 12

              // ── Radio indicator ──────────────────────────────────────────
              AnimatedSwitcher(
                duration: FixoDurations.fast,
                child: selected
                    ? Container(
                        key: const ValueKey('checked'),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: th.brand,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: th.onBrand,
                        ),
                      )
                    : Container(
                        key: const ValueKey('unchecked'),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: DesignTokens.borderControl(isDark),
                            width: 1.5,
                          ),
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

class PasswordRules extends StatelessWidget {
  final String password;
  const PasswordRules({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
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
                    children: [
                      Icon(
                        rule.value
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        size: 20,
                      ),
                      const SizedBox(width: Space.s2),
                      Expanded(
                        child: Text(
                          rule.key,
                          style: Theme.of(context).textTheme.bodyMedium,
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

@Preview(name: 'Auth controls', brightness: Brightness.light)
@Preview(name: 'Auth controls dark', brightness: Brightness.dark)
Widget authControlsPreview() => const Material(
  child: Padding(
    padding: EdgeInsets.all(Space.s6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthGoogleButton(),
        PasswordRules(password: 'Example1!'),
      ],
    ),
  ),
);
