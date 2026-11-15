import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/th_components.dart';

/// The designed error/empty states from the v1.6.2 mockups
/// (frames-states.html `E-*`): illustration + section headline + secondary
/// body + optional primary CTA + optional ghost action.
///
/// Illustrations ship as paired `il-XX-light` / `il-XX-dark` art (same pair
/// the mockups switch between), so the one theme branch here mirrors the
/// source of truth — it is an asset swap, not a colour branch.
enum DesignedStateVariant {
  /// E-no-messages.
  noMessages,

  /// E-empty-leads. [area] personalises the body when known.
  emptyLeads,

  /// E-job-not-found.
  jobNotFound,

  /// E-job-unavailable.
  jobUnavailable,

  /// E-request-expired (tradie lead already accepted elsewhere).
  requestExpired,
}

class DesignedEmptyState extends StatelessWidget {
  final DesignedStateVariant variant;

  /// Tradie lead area ("Grey Lynn") woven into the empty-leads copy.
  final String? area;

  /// Overrides the mockup CTA (label + handler). Defaults per variant.
  final String? actionLabel;
  final VoidCallback? onAction;

  const DesignedEmptyState({
    super.key,
    required this.variant,
    this.area,
    this.actionLabel,
    this.onAction,
  });

  ({String asset, String title, String body, String? cta, String? ghost}) _copy(
    BuildContext context,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String il(String id) =>
        'assets/design/$id-${isDark ? 'dark' : 'light'}.svg';

    return switch (variant) {
      DesignedStateVariant.noMessages => (
        asset: il('il-02'),
        title: 'No messages yet',
        body:
            'When you\'re matched with a tradie, your chat will show up here.',
        cta: null,
        ghost: null,
      ),
      DesignedStateVariant.emptyLeads => (
        asset: il('il-08'),
        title: 'No new leads right now',
        body:
            'We\'ll ping you when a job near ${area ?? 'you'} matches your services.',
        cta: null,
        ghost: null,
      ),
      DesignedStateVariant.jobNotFound => (
        asset: il('il-04'),
        title: 'We couldn\'t find this job',
        body: 'It may have been removed or the link is old.',
        cta: 'Back to my jobs',
        ghost: 'Contact support',
      ),
      DesignedStateVariant.jobUnavailable => (
        asset: il('il-04'),
        title: 'This job is no longer available',
        body: 'The homeowner cancelled it or it was filled by someone else.',
        cta: 'Back to my jobs',
        ghost: null,
      ),
      DesignedStateVariant.requestExpired => (
        asset: il('il-03'),
        title: 'This request expired',
        body: 'Another tradie may have accepted this job. New leads arrive all the time.',
        cta: 'Back to leads',
        ghost: null,
      ),
    };
  }

  void _defaultAction(BuildContext context) {
    switch (variant) {
      case DesignedStateVariant.jobNotFound ||
          DesignedStateVariant.jobUnavailable:
        context.go('/jobs');
      case DesignedStateVariant.requestExpired:
        context.go('/tradie');
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final copy = _copy(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            THArt(asset: copy.asset, semanticLabel: copy.title),
            const SizedBox(height: Space.s5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    copy.title,
                    textAlign: TextAlign.center,
                    style: THType.section.copyWith(color: th.text),
                  ),
                  const SizedBox(height: Space.s2),
                  Text(
                    copy.body,
                    textAlign: TextAlign.center,
                    style: THType.secondary.copyWith(color: th.textSoft),
                  ),
                ],
              ),
            ),
            if (copy.cta != null) ...[
              const SizedBox(height: Space.s6),
              SizedBox(
                width: Sizes.buttonSecondary * 4,
                child: FixoPrimaryButton(
                  label: actionLabel ?? copy.cta!,
                  onPressed: onAction ?? () => _defaultAction(context),
                ),
              ),
            ],
            if (copy.ghost != null) ...[
              const SizedBox(height: Space.s3),
              SizedBox(
                width: Sizes.buttonSecondary * 4,
                child: FixoGhostButton(label: copy.ghost!, onPressed: () {}),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
