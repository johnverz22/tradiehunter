// Content cards of the v2 tradie request detail (`tr_lead`, plan 5.2). Pure
// presentation: values come from `tr_lead_mapper.dart`, actions from the
// screen. Gap register: no homeowner stats / access / distance rows (G-17,
// G-18), no fabricated timeline subtitles.
import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'tr_common.dart';
import 'tr_lead_mapper.dart';
import 'tr_lead_states.dart';

/// Offer state card: live countdown, check error with retry, or "gone".
class TrLeadOfferCard extends StatelessWidget {
  const TrLeadOfferCard({
    super.key,
    required this.offer,
    required this.offerChecked,
    required this.offerError,
    required this.onRetry,
    required this.onExpired,
  });

  final JobOffer? offer;
  final bool offerChecked;
  final bool offerError;
  final VoidCallback onRetry;
  final VoidCallback onExpired;

  @override
  Widget build(BuildContext context) {
    if (offerError) return TrOfferCheckError(onRetry: onRetry);
    final o = offer;
    if (o != null) {
      return THCard(
        padding: Space.s4,
        tone: THCardTone.accent,
        children: [
          TrOfferCountdown(offer: o, onExpired: onExpired),
          const SizedBox(height: Space.s2),
          const THText(
            'Online tradies get offers first. If you don’t respond, it goes '
            'to the next tradie.',
            style: THTextStyle.meta,
            tone: THTone.soft,
          ),
        ],
      );
    }
    if (offerChecked) return const TrOfferGone();
    return const SizedBox.shrink();
  }
}

/// Category, title and description.
class TrLeadJobCard extends StatelessWidget {
  const TrLeadJobCard({super.key, required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) => THCard(
    padding: Space.s4,
    children: [
      Wrap(
        spacing: Space.s1_5,
        runSpacing: Space.s1_5,
        children: [THBadge(job.category, kind: THBadgeKind.brand)],
      ),
      const SizedBox(height: Space.s2_5),
      THText(job.title, style: THTextStyle.h2),
      const SizedBox(height: Space.s1_5),
      THText(
        job.description?.isNotEmpty == true
            ? job.description!
            : 'No description provided.',
        style: THTextStyle.body,
        tone: THTone.soft,
      ),
    ],
  );
}

/// Large total with the hours × rate breakdown beneath (v1 `_PriceBlock`).
class TrLeadPriceCard extends StatelessWidget {
  const TrLeadPriceCard({super.key, required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final breakdown = trPriceBreakdown(job);
    return THCard(
      padding: Space.s4,
      children: [
        THText(trPriceTotal(job), style: THTextStyle.moneyLg),
        if (breakdown != null) ...[
          const SizedBox(height: Space.s1),
          THText(breakdown, style: THTextStyle.meta, tone: THTone.soft),
        ],
      ],
    );
  }
}

/// Text scale from which long badge values switch to wrapping text.
const double _wrapAtTextScale = 1.3;

/// Suburb plus the (truthful) address-sharing rule, and the schedule row
/// when the job has a scheduled start.
class TrLeadLocationCard extends StatelessWidget {
  const TrLeadLocationCard({super.key, required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final schedule = trScheduleLabel(job);
    // THKeyValue lays a badge out unbounded and the badge never wraps, so the
    // long rule overflows on a narrow phone at large text. From the same scale
    // THStickyBar stacks at, show it as wrapping text instead.
    final largeText =
        MediaQuery.textScalerOf(context).scale(1.0) >= _wrapAtTextScale;
    return THCard(
      padding: Space.s4,
      children: [
        THKeyValue('Area', trLocationLabel(job), bold: true),
        if (largeText)
          const THKeyValue(
            'Exact address',
            'Shared after the job is booked',
            tone: THTone.brand,
            divider: true,
          )
        else
          const THKeyValue(
            'Exact address',
            'Shared after the job is booked',
            badge: THBadgeKind.brand,
            divider: true,
          ),
        if (schedule != null)
          THKeyValue('Scheduled', schedule, bold: true, divider: true),
      ],
    );
  }
}

/// Bottom bar: Decline + Accept / Submit quote, or why there is nothing to
/// answer.
class TrLeadActions extends StatelessWidget {
  const TrLeadActions({
    super.key,
    required this.bar,
    required this.busy,
    required this.onDecline,
    required this.onAccept,
    required this.onSubmitQuote,
  });

  final TrLeadBar bar;
  final bool busy;
  final VoidCallback onDecline;
  final VoidCallback onAccept;
  final VoidCallback onSubmitQuote;

  @override
  Widget build(BuildContext context) {
    if (bar == TrLeadBar.gone || bar == TrLeadBar.expired) {
      return THStickyBar(
        children: [
          Expanded(
            child: THText(
              trLeadBarMessage(bar),
              style: THTextStyle.body,
              tone: THTone.danger,
              align: TextAlign.center,
            ),
          ),
        ],
      );
    }
    final quote = bar == TrLeadBar.quote;
    return THStickyBar(
      children: [
        THButton(
          key: const Key('decline_offer_button'),
          label: 'Decline',
          kind: THButtonKind.secondary,
          fullWidth: false,
          onPressed: busy ? null : onDecline,
        ),
        Expanded(
          child: THButton(
            key: quote ? const Key('submit_quote_button') : null,
            label: quote ? 'Submit quote' : 'Accept Job',
            kind: THButtonKind.accent,
            loading: busy,
            onPressed: busy ? null : (quote ? onSubmitQuote : onAccept),
          ),
        ),
      ],
    );
  }
}
