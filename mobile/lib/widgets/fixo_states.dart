import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'fixo_buttons.dart';

/// Shared loading / empty / error states so every screen behaves the same.
///
/// Usage:
/// - Loading: `const FixoLoading(label: 'Loading jobs…')`
/// - Empty: `FixoEmptyState(icon: Icons.work_off_outlined, title: ..., actionLabel: ..., onAction: ...)`
/// - Error: `FixoErrorState(message: ..., onRetry: ...)`
class FixoLoading extends StatelessWidget {
  final String? label;

  const FixoLoading({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (label != null) ...[
            const SizedBox(height: DesignTokens.space4),
            Text(
              label!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class FixoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FixoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: DesignTokens.space4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: DesignTokens.space2),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DesignTokens.space4),
              FixoPrimaryButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class FixoErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const FixoErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: DesignTokens.red),
            const SizedBox(height: DesignTokens.space4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: DesignTokens.space4),
              FixoGhostButton(label: 'Try again', onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

/// Constrains content to a readable width on tablets / landscape.
/// Wrap ListView children or form columns with this.
class FixoResponsive extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const FixoResponsive(
      {super.key, required this.child, this.maxWidth = 640});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
