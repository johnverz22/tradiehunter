// Non-happy-path states of the v2 tradie request detail (`tr_lead`, plan
// 5.2): offer gone, offer check failed, request not found. Copy is the v1
// copy; none of these is ever a blank screen.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_state_view.dart';

/// The pending-offer fetch succeeded but returned none: the offer lapsed or
/// was already answered. A truthful state, not a countdown stuck at zero.
class TrOfferGone extends StatelessWidget {
  const TrOfferGone({super.key});

  @override
  Widget build(BuildContext context) => const THCard(
    padding: Space.s3_5,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: Space.s3,
        children: [
          THIcon(Icons.timer_off_outlined, tone: THTone.soft),
          Expanded(
            child: THText(
              'This offer is no longer available — it may have expired or '
              'already been answered.',
              style: THTextStyle.meta,
              tone: THTone.soft,
            ),
          ),
        ],
      ),
    ],
  );
}

/// The pending-offer fetch failed (distinct from "no offer"): offer a retry.
class TrOfferCheckError extends StatelessWidget {
  const TrOfferCheckError({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => THCard(
    padding: Space.s3_5,
    children: [
      const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: Space.s3,
        children: [
          THIcon(Icons.cloud_off_outlined, tone: THTone.accent),
          Expanded(
            child: THText(
              'Could not check this offer.',
              style: THTextStyle.title,
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.s2_5),
      THButton(
        label: 'Try again',
        kind: THButtonKind.secondary,
        size: THButtonSize.sm,
        icon: Icons.refresh_rounded,
        onPressed: onRetry,
      ),
    ],
  );
}

/// Full-page body when the request cannot be found / has expired.
class TrRequestNotFound extends StatelessWidget {
  const TrRequestNotFound({super.key, required this.onAction});
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => ThStateView.empty(
    icon: Icons.hourglass_disabled_rounded,
    title: 'This request expired',
    body:
        'Another tradie may have accepted this job, or the offer window '
        'closed.',
    actionLabel: 'View open leads',
    onAction: onAction,
  );
}
