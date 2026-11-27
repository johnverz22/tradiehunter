import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';

/// Plan 10 Q7.9: human-readable countdown for an open-board project's
/// [Job.quotesCloseAtUtc]. Null when no close time is set.
String? thQuotesCloseLabel(DateTime? closeAtUtc, {DateTime? nowUtc}) {
  if (closeAtUtc == null) return null;
  final diff = closeAtUtc.toUtc().difference((nowUtc ?? DateTime.now()).toUtc());
  if (diff <= Duration.zero) return 'Quotes closed';
  if (diff.inDays >= 1) {
    final days = diff.inDays;
    return days == 1 ? 'Quotes close in 1 day' : 'Quotes close in $days days';
  }
  if (diff.inHours >= 1) {
    final hours = diff.inHours;
    return hours == 1 ? 'Quotes close in 1 hour' : 'Quotes close in $hours hours';
  }
  final mins = diff.inMinutes < 1 ? 1 : diff.inMinutes;
  return mins == 1 ? 'Quotes close in 1 minute' : 'Quotes close in $mins minutes';
}

/// Job title for the quotes app-bar subtitle. `null` means the fetch failed
/// or is in progress; the subtitle shows the count alone in that case (G-6).
final quotesJobProvider = FutureProvider.autoDispose.family<Job?, String>(
  (ref, jobId) => ref.watch(jobsRepositoryProvider).getJobById(jobId),
);

/// v2 presentation for the existing project quote comparison contract.
class HoQuotesScreen extends ConsumerStatefulWidget {
  const HoQuotesScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<HoQuotesScreen> createState() => _HoQuotesScreenState();
}

class _HoQuotesScreenState extends ConsumerState<HoQuotesScreen> {
  Future<void> _reload() =>
      ref.read(quotesProvider(widget.jobId).notifier).load();

  Future<void> _accept(Quote quote) async {
    final notifier = ref.read(quotesProvider(widget.jobId).notifier);
    var result = await notifier.acceptQuote(
      quote.id,
      confirmWrittenContract: false,
    );
    if (!mounted) return;
    if (result.accepted) {
      THNotice.success(
        context,
        'Quote accepted — ${quote.displayName} is booked. Payment happens when the job is done.',
      );
      context.pushReplacement('/jobs/${widget.jobId}');
      return;
    }
    if (result.requiresWrittenContract) {
      final confirmed = await _confirmContract(result.message);
      if (!mounted || !confirmed) return;
      result = await notifier.acceptQuote(
        quote.id,
        confirmWrittenContract: true,
      );
      if (!mounted) return;
      if (result.accepted) {
        THNotice.success(
          context,
          'Quote accepted — the job is booked. Payment happens when the job is done.',
        );
        context.pushReplacement('/jobs/${widget.jobId}');
      }
    }
    if (result.failed && mounted) {
      THNotice.error(context, result.message ?? 'Could not accept the quote.');
    }
  }

  Future<void> _view(Quote quote) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => ThScope(
      themeMode: ref.read(themeModeProvider),
      child: _QuoteDetailSheet(
        quote: quote,
        onAccept: () {
          Navigator.of(sheetContext).pop();
          _accept(quote);
        },
      ),
    ),
  );

  Future<bool> _confirmContract(String? message) async {
    var checked = false;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => ThScope(
          themeMode: ref.read(themeModeProvider),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Space.s4,
              Space.s5,
              Space.s4,
              Space.s5 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const THText(
                  'Written contract required',
                  style: THTextStyle.title,
                ),
                const SizedBox(height: Space.s3),
                THText(
                  message ?? 'A written contract is legally required for residential building work at or above the legal threshold (Building Act s362F).',
                  style: THTextStyle.body,
                  tone: THTone.soft,
                ),
                const SizedBox(height: Space.s3),
                Semantics(
                  identifier: 'written_contract_checkbox',
                  child: CheckboxListTile(
                    key: const Key('written_contract_checkbox'),
                    value: checked,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const THText(
                      'I have a written contract with this tradie',
                      style: THTextStyle.body,
                    ),
                    onChanged: (value) =>
                        setSheetState(() => checked = value ?? false),
                  ),
                ),
                const SizedBox(height: Space.s2),
                Row(
                  children: [
                    Expanded(
                      child: THButton(
                        label: 'Not yet',
                        kind: THButtonKind.secondary,
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: Space.s3),
                    Expanded(
                      child: THButton(
                        key: const Key('contract_confirm_button'),
                        label: 'Confirm & accept',
                        kind: THButtonKind.accent,
                        onPressed: checked
                            ? () => Navigator.of(sheetContext).pop(true)
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: Builder(
      builder: (context) {
        final state = ref.watch(quotesProvider(widget.jobId));
        final quotes = state.quotes;
        // Job title for the subtitle — G-6: omit rather than guess if null.
        final job = ref.watch(quotesJobProvider(widget.jobId)).valueOrNull;
        final jobTitle = job?.title;
        // Plan 10 Q3.4 / Q7.9: "N of M received" when the server told us M;
        // "N received" for open-board jobs (quotesRequested == null).
        final requested = job?.quotesRequested;
        final receivedLabel = requested == null
            ? '${quotes.length} received'
            : '${quotes.length} of ${requested < quotes.length ? quotes.length : requested} received';
        final closeLabel = thQuotesCloseLabel(job?.quotesCloseAtUtc);
        final isOpenBoard = job?.openToBoard ?? false;
        final body = state.isLoading && quotes.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.error != null && quotes.isEmpty
            ? _StatePanel(
                title: 'Quotes could not load',
                message: state.error!,
                action: 'Try again',
                onPressed: _reload,
              )
            : quotes.isEmpty
            ? _StatePanel(
                title: 'No quotes yet',
                message: isOpenBoard
                    ? 'Nearby tradies can see your project and send quotes. You will get a notification as each one arrives.'
                    : 'Tradies you asked are preparing their quotes. You will get a notification as each one arrives.',
                badge: closeLabel,
              )
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  padding: EdgeInsets.all(Space.s1),
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: quotes.length + (closeLabel != null ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: Space.s3),
                  itemBuilder: (context, index) {
                    if (closeLabel != null && index == 0) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: THBadge(
                          closeLabel,
                          key: const Key('quotes_close_badge'),
                          kind: THBadgeKind.brand,
                        ),
                      );
                    }
                    final quote = quotes[closeLabel != null ? index - 1 : index];
                    return _QuoteCard(
                      quote: quote,
                      accepting: state.acceptingQuoteId == quote.id,
                      onView: () => _view(quote),
                      onAccept: () => _accept(quote),
                    );
                  },
                ),
              );
        return THScaffold(
          appBar: THAppBar(
            title: 'Quotes',
            subtitle: quotes.isEmpty
                ? null
                : jobTitle != null
                ? '$jobTitle · $receivedLabel'
                : receivedLabel,
          ),
          scrollable: false,
          body: body,
          stickyBar: quotes.isEmpty
              ? null
              : THStickyBar(
                  children: const [
                    THText(
                      'Pay only when the job is done and you approve the total.',
                      style: THTextStyle.meta,
                      tone: THTone.soft,
                      align: TextAlign.center,
                    ),
                  ],
                ),
        );
      },
    ),
  );
}

// ── Quote presentation helpers (shared by the card and the detail sheet) ─────

/// Full price line used in the detail view.
String _fullPrice(Quote quote) {
  if (quote.isFixed) return formatMoneyOrDash(quote.amount);
  if (quote.isEstimateRange) {
    final min = quote.minAmount;
    final max = quote.maxAmount;
    if (min == null && max == null) return '—';
    if (min != null && max != null) {
      return '${formatMoney(min)} – ${formatMoney(max)}';
    }
    return formatMoneyOrDash(min ?? max);
  }
  if (quote.isHourlyWithCap) {
    final rate = quote.amount;
    return rate == null
        ? '—'
        : '${formatRate(rate)} · cap ${formatMoneyOrDash(quote.cap)}';
  }
  return '—';
}

/// Headline money on the compact card (mockup `ho_quotes`).
String _compactPrice(Quote quote) {
  if (quote.isHourlyWithCap) {
    final rate = quote.amount;
    return rate == null ? '—' : formatRate(rate);
  }
  return _fullPrice(quote);
}

/// Caption under the compact price: `fixed · incl. GST`, `estimate · no GST`,
/// `hourly · cap $2,000.00 · incl. GST`.
String _caption(Quote quote) {
  final model = quote.isFixed
      ? 'fixed'
      : quote.isEstimateRange
      ? 'estimate'
      : quote.isHourlyWithCap
      ? 'hourly · cap ${formatMoneyOrDash(quote.cap)}'
      : null;
  final gst = quote.gstIncluded ? 'incl. GST' : 'no GST';
  return model == null ? gst : '$model · $gst';
}

/// `N days` under two weeks, otherwise `N weeks` (rounded).
String _durationLabel(int days) {
  if (days < 14) return days == 1 ? '1 day' : '$days days';
  return '${(days / 7).round()} weeks';
}

String _dateLabel(DateTime date) =>
    '${date.toLocal().day}/${date.toLocal().month}/${date.toLocal().year}';

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.accepting,
    required this.onView,
    required this.onAccept,
  });
  final Quote quote;
  final bool accepting;
  final VoidCallback onView;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final decided = !quote.isOpen;
    final days = quote.estimatedDurationDays;
    final meta = [
      if (quote.rating != null) quote.rating!.toStringAsFixed(1),
      if (days != null) _durationLabel(days),
    ].join(' · ');
    return THCard(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            THAvatar(quote.initials.isEmpty ? '?' : quote.initials),
            const SizedBox(width: Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  THText(quote.displayName, style: THTextStyle.title),
                  if (meta.isNotEmpty)
                    THText(
                      meta,
                      style: THTextStyle.meta,
                      tone: THTone.soft,
                    ),
                  if (quote.verified) ...[
                    const SizedBox(height: Space.s1),
                    const THBadge(
                      'Verified',
                      kind: THBadgeKind.ok,
                      icon: Icons.verified_outlined,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Space.s2),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  THText(
                    _compactPrice(quote),
                    style: THTextStyle.money,
                    align: TextAlign.end,
                  ),
                  THText(
                    _caption(quote),
                    style: THTextStyle.meta,
                    tone: THTone.soft,
                    align: TextAlign.end,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.s3),
        Row(
          children: [
            Expanded(
              child: THButton(
                key: Key('view_quote_${quote.id}'),
                label: 'View quote',
                kind: THButtonKind.secondary,
                size: THButtonSize.sm,
                onPressed: onView,
              ),
            ),
            const SizedBox(width: Space.s3),
            Expanded(
              child: decided
                  ? Align(
                      alignment: Alignment.center,
                      child: THBadge(
                        quote.status,
                        kind: quote.status == Quote.statusAccepted
                            ? THBadgeKind.ok
                            : THBadgeKind.brand,
                      ),
                    )
                  : THButton(
                      key: Key('accept_quote_${quote.id}'),
                      label: accepting ? 'Accepting…' : 'Accept',
                      kind: THButtonKind.accent,
                      size: THButtonSize.sm,
                      loading: accepting,
                      onPressed: accepting ? null : onAccept,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Full quote detail opened from "View quote" (plan 10 D2: bottom sheet).
/// Accept here goes through the same `_accept` path (incl. the written-contract
/// gate) as the card.
class _QuoteDetailSheet extends StatelessWidget {
  const _QuoteDetailSheet({required this.quote, required this.onAccept});
  final Quote quote;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final days = quote.estimatedDurationDays;
    return ConstrainedBox(
      key: Key('quote_detail_${quote.id}'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.s4,
          Space.s5,
          Space.s4,
          Space.s5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                THAvatar(quote.initials.isEmpty ? '?' : quote.initials),
                const SizedBox(width: Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      THText(quote.displayName, style: THTextStyle.title),
                      if (quote.rating != null && quote.reviewCount != null)
                        THText(
                          '${quote.rating!.toStringAsFixed(1)} · ${quote.reviewCount} reviews',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                    ],
                  ),
                ),
                if (quote.verified)
                  const THBadge(
                    'Verified',
                    kind: THBadgeKind.ok,
                    icon: Icons.verified_outlined,
                  ),
              ],
            ),
            const SizedBox(height: Space.s3),
            THText(_fullPrice(quote), style: THTextStyle.money),
            THText(
              quote.gstIncluded ? 'Incl. GST' : 'No GST charged',
              style: THTextStyle.meta,
              tone: THTone.soft,
            ),
            if (quote.cap != null)
              THKeyValue(
                'Price cap',
                '${formatMoneyOrDash(quote.cap)} · further costs need your approval',
              ),
            if (quote.inclusions?.isNotEmpty == true)
              THKeyValue('Includes', quote.inclusions!),
            if (quote.exclusions?.isNotEmpty == true)
              THKeyValue('Does not include', quote.exclusions!),
            THKeyValue(
              'Materials',
              quote.materialsIncluded ? 'Included' : 'By you',
            ),
            if (quote.proposedStartUtc != null)
              THKeyValue('Proposed start', _dateLabel(quote.proposedStartUtc!)),
            if (days != null)
              THKeyValue('Estimated duration', _durationLabel(days)),
            if (quote.validUntilUtc != null)
              THKeyValue('Valid until', _dateLabel(quote.validUntilUtc!)),
            const SizedBox(height: Space.s3),
            if (quote.isOpen)
              THButton(
                key: Key('quote_detail_accept_${quote.id}'),
                label: 'Accept quote',
                kind: THButtonKind.accent,
                onPressed: onAccept,
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: THBadge(
                  quote.status,
                  kind: quote.status == Quote.statusAccepted
                      ? THBadgeKind.ok
                      : THBadgeKind.brand,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.title,
    required this.message,
    this.badge,
    this.action,
    this.onPressed,
  });
  final String title;
  final String message;
  final String? badge;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(Space.s4),
      child: THCard(
        children: [
          THText(title, style: THTextStyle.title, align: TextAlign.center),
          if (badge != null) ...[
            const SizedBox(height: Space.s2),
            Center(
              child: THBadge(
                badge!,
                key: const Key('quotes_close_badge'),
                kind: THBadgeKind.brand,
              ),
            ),
          ],
          const SizedBox(height: Space.s2),
          THText(
            message,
            style: THTextStyle.body,
            tone: THTone.soft,
            align: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: Space.s3),
            THButton(label: action!, onPressed: onPressed),
          ],
        ],
      ),
    ),
  );
}
