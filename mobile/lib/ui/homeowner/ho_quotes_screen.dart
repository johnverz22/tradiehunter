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
        final jobTitle = ref
            .watch(quotesJobProvider(widget.jobId))
            .valueOrNull
            ?.title;
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
            ? const _StatePanel(
                title: 'No quotes yet',
                message: 'Tradies you asked are preparing their quotes. You will get a notification as each one arrives.',
              )
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  padding: EdgeInsets.all(Space.s1),
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: quotes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.s3),
                  itemBuilder: (context, index) => _QuoteCard(
                    quote: quotes[index],
                    accepting: state.acceptingQuoteId == quotes[index].id,
                    onAccept: () => _accept(quotes[index]),
                  ),
                ),
              );
        return THScaffold(
          appBar: THAppBar(
            title: 'Quotes',
            subtitle: quotes.isEmpty
                ? null
                : jobTitle != null
                ? '$jobTitle · ${quotes.length} received'
                : '${quotes.length} received',
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

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.accepting,
    required this.onAccept,
  });
  final Quote quote;
  final bool accepting;
  final VoidCallback onAccept;

  String get _price {
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

  @override
  Widget build(BuildContext context) {
    final decided =
        quote.status == Quote.statusAccepted ||
        quote.status == Quote.statusDeclined ||
        quote.status == Quote.statusWithdrawn ||
        quote.status == Quote.statusExpired;
    return THCard(
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
        THText(_price, style: THTextStyle.money),
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
        if (quote.estimatedDurationDays != null)
          THKeyValue(
            'Estimated duration',
            '${quote.estimatedDurationDays} days',
          ),
        if (decided)
          THBadge(
            quote.status,
            kind: quote.status == Quote.statusAccepted
                ? THBadgeKind.ok
                : THBadgeKind.brand,
          )
        else
          THButton(
            key: Key('accept_quote_${quote.id}'),
            label: accepting ? 'Accepting…' : 'Accept quote',
            kind: THButtonKind.accent,
            loading: accepting,
            onPressed: accepting ? null : onAccept,
          ),
      ],
    );
  }

  String _dateLabel(DateTime date) =>
      '${date.toLocal().day}/${date.toLocal().month}/${date.toLocal().year}';
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.title,
    required this.message,
    this.action,
    this.onPressed,
  });
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(Space.s4),
      child: THCard(
        children: [
          THText(title, style: THTextStyle.title, align: TextAlign.center),
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
