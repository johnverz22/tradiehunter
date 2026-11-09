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
    return _FixoStateLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (label != null) ...[
            const SizedBox(height: DesignTokens.space4),
            Text(
              label!,
              textAlign: TextAlign.center,
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

class _FixoStateLayout extends StatelessWidget {
  final Widget child;

  const _FixoStateLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        primary: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(child: child),
        ),
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
    return _FixoStateLayout(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: DesignTokens.space4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FW.semibold,
              ),
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
    final isDark = theme.brightness == Brightness.dark;
    return _FixoStateLayout(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: DesignTokens.inkDanger(isDark),
            ),
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

  const FixoResponsive({super.key, required this.child, this.maxWidth = 640});

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

// ─── Responsive breakpoints ────────────────────────────────────────────────

/// iPad mini portrait threshold — master-detail splits appear here.
const double kBreakpointMasterDetail = 744.0;

/// Approximate 13-inch iPad landscape — left-rail navigation appears here.
const double kBreakpointLeftRail = 1024.0;

/// Canonical readable-column max width for forms, lists and chat.
const double kMaxContentWidth = 640.0;

/// Centers and caps content to [maxWidth] (defaults to [kMaxContentWidth])
/// so forms, lists and reading views never stretch across wide iPad screens (V16-18).
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Left panel width in the master-detail split.
const double kMasterPanelWidth = 360.0;

// ─── Master-detail layout ──────────────────────────────────────────────────

/// Two-column master-detail split used at ≥[kBreakpointMasterDetail] width.
///
/// - At narrow widths the [master] fills the screen (phone default).
/// - At ≥744pt the [master] (360px) and [detail] panel sit side by side.
/// - When nothing is selected in the master panel [emptyDetail] is shown in
///   the right pane — defaults to a friendly "Select an item" placeholder.
///
/// The [detailVisible] flag controls whether the right panel shows [detail]
/// or [emptyDetail]. Toggle it in the parent state when the user taps a row.
class MasterDetailLayout extends StatelessWidget {
  final Widget master;
  final Widget detail;
  final Widget? emptyDetail;
  final bool detailVisible;

  const MasterDetailLayout({
    super.key,
    required this.master,
    required this.detail,
    this.emptyDetail,
    this.detailVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kBreakpointMasterDetail;
        if (!isWide) {
          // Phone: full-screen master only; detail navigated via GoRouter.
          return master;
        }

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final dividerColor = DesignTokens.paperLine(isDark);

        final rightPanel = detailVisible
            ? detail
            : (emptyDetail ?? _DefaultEmptyDetail());

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: kMasterPanelWidth, child: master),
            VerticalDivider(width: 1, color: dividerColor),
            Expanded(child: rightPanel),
          ],
        );
      },
    );
  }
}

class _DefaultEmptyDetail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: Space.s3),
          Text(
            'Select an item to view details',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
