import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../repositories/jobs_repository.dart';
import '../../theme/design_tokens.dart';
import '../../utils/money.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../../widgets/fixo_states.dart';
import '../widgets/sticky_action_bar.dart';
import '../../feedback/fixo_notice.dart';

/// Quotes comparison screen (v1.7 P12-24, project jobs only).
///
/// Route: `/jobs/:jobId/quotes`. Shows every quote submitted for the job
/// (contract #11) side by side — price with the D8 GST label, inclusions,
/// start date, rating — with an Accept quote action per card (contract #13).
///
/// Accepting at or above the written-contract threshold first returns the
/// Building Act s362F gate (409 `requiresWrittenContractConfirmation`): the
/// homeowner must confirm a written contract exists before the job books.
/// Payment still happens at completion — nothing here charges anyone.
class QuotesScreen extends ConsumerStatefulWidget {
  final String jobId;

  const QuotesScreen({super.key, required this.jobId});

  @override
  ConsumerState<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends ConsumerState<QuotesScreen> {
  Future<void> _reload() =>
      ref.read(quotesProvider(widget.jobId).notifier).load();

  Future<void> _acceptQuote(Quote quote) async {
    final notifier = ref.read(quotesProvider(widget.jobId).notifier);
    final result = await notifier.acceptQuote(
      quote.id,
      confirmWrittenContract: false,
    );
    if (!mounted) return;

    if (result.accepted) {
      FixoNotice.success(
        context,
        'Quote accepted — ${resultMessageName(quote)} is booked. Payment happens when the job is done.',
      );
      context.pushReplacement('/jobs/${widget.jobId}');
      return;
    }

    if (result.requiresWrittenContract) {
      final confirmed = await _confirmWrittenContract(result);
      if (!mounted) return;
      if (!confirmed) return; // homeowner dismissed the gate — stay on the list

      final retry = await notifier.acceptQuote(
        quote.id,
        confirmWrittenContract: true,
      );
      if (!mounted) return;
      if (retry.accepted) {
        FixoNotice.success(
          context,
          'Quote accepted — the job is booked. Payment happens when the job is done.',
        );
        context.pushReplacement('/jobs/${widget.jobId}');
      } else if (retry.failed) {
        FixoNotice.error(
          context,
          retry.message ?? 'Could not accept the quote.',
        );
      }
      return;
    }

    if (result.failed) {
      FixoNotice.error(
        context,
        result.message ?? 'Could not accept the quote.',
      );
    }
  }

  String resultMessageName(Quote quote) => quote.displayName;

  /// P12-25 gate: the Building Act s362F written-contract notice with a
  /// required confirmation checkbox. Returns true only when the homeowner
  /// ticked the box and confirmed.
  Future<bool> _confirmWrittenContract(QuoteAcceptResult gate) async {
    var checked = false;
    final theme = Theme.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            Space.s4,
            Space.s5,
            Space.s4,
            Space.s5 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Written contract required',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FW.semibold,
                ),
              ),
              SizedBox(height: Space.s3),
              Text(
                gate.message ??
                    'A written contract is legally required for residential '
                        'building work at or above the legal threshold '
                        '(Building Act s362F).',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: Space.s4),
              CheckboxListTile(
                value: checked,
                onChanged: (value) =>
                    setSheetState(() => checked = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text('I have a written contract with this tradie'),
              ),
              SizedBox(height: Space.s2),
              Row(
                children: [
                  Expanded(
                    child: FixoSecondaryButton(
                      label: 'Not yet',
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                    ),
                  ),
                  SizedBox(width: Space.s3),
                  Expanded(
                    child: FixoPrimaryButton(
                      label: 'Confirm & accept',
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
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(quotesProvider(widget.jobId));

    Widget body;
    if (state.isLoading && state.quotes.isEmpty) {
      body = const FixoLoading(label: 'Loading quotes…');
    } else if (state.error != null && state.quotes.isEmpty) {
      body = FixoErrorState(
        message: 'Quotes could not load: ${state.error}',
        onRetry: _reload,
      );
    } else if (state.quotes.isEmpty) {
      body = const FixoEmptyState(
        icon: Icons.description_outlined,
        title: 'No quotes yet',
        subtitle:
            'Tradies you asked are preparing their quotes — you will get a '
            'notification as each one arrives.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _reload,
        child: ListView.separated(
          padding: EdgeInsets.all(Space.s4),
          itemCount: state.quotes.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: Space.s3),
          itemBuilder: (context, index) => QuoteCard(
            quote: state.quotes[index],
            accepting: state.acceptingQuoteId == state.quotes[index].id,
            onAccept: () => _acceptQuote(state.quotes[index]),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const FixoGradientAppBar(title: 'Quotes'),
      body: body,
      // Nothing here charges anyone — payment happens at completion (P12-24).
      bottomNavigationBar: state.quotes.isEmpty
          ? null
          : StickyActionBar(
              child: Text(
                'Pay only when the job is done and you approve the total.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}

/// One quote card: tradie identity, price with GST label, scope details.
class QuoteCard extends StatelessWidget {
  final Quote quote;
  final bool accepting;
  final VoidCallback onAccept;

  const QuoteCard({
    super.key,
    required this.quote,
    required this.accepting,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<THColors>()!;
    final isAccepted = quote.status == Quote.statusAccepted;
    final isDecided =
        isAccepted ||
        quote.status == Quote.statusDeclined ||
        quote.status == Quote.statusWithdrawn ||
        quote.status == Quote.statusExpired;

    return FixoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: Sizes.avatarRadius * 2,
                height: Sizes.avatarRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.avTradie,
                ),
                alignment: Alignment.center,
                child: Text(
                  quote.initials.isEmpty ? '?' : quote.initials,
                  style: TextStyle(
                    fontFamily: TypeTokens.fontDisplay,
                    fontSize: DesignTokens.fontSizeH3,
                    fontWeight: FW.semibold,
                    color: colors.onAvTradie,
                  ),
                ),
              ),
              SizedBox(width: Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FW.semibold,
                      ),
                    ),
                    if (quote.rating != null && quote.reviewCount != null)
                      Text(
                        '${quote.rating!.toStringAsFixed(1)} '
                        '(${quote.reviewCount} reviews)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (quote.verified)
                Icon(
                  Icons.verified_outlined,
                  size: Sizes.iconSm,
                  color: DesignTokens.amber,
                ),
            ],
          ),
          SizedBox(height: Space.s3),
          Text(
            _priceLine(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FW.semibold,
            ),
          ),
          SizedBox(height: Space.s1),
          Text(
            quote.gstIncluded ? 'Incl. GST' : 'No GST charged',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (quote.cap != null) ...[
            SizedBox(height: Space.s2),
            Text(
              'Cap ${formatMoneyOrDash(quote.cap)} — above the cap needs your approval first.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (quote.inclusions != null && quote.inclusions!.isNotEmpty) ...[
            SizedBox(height: Space.s3),
            _DetailBlock(label: 'Includes', text: quote.inclusions!),
          ],
          if (quote.exclusions != null && quote.exclusions!.isNotEmpty) ...[
            SizedBox(height: Space.s2),
            _DetailBlock(label: 'Does not include', text: quote.exclusions!),
          ],
          SizedBox(height: Space.s3),
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [
              if (quote.proposedStartUtc != null)
                _MetaChip(
                  icon: Icons.event_outlined,
                  label: _dateLabel(quote.proposedStartUtc!),
                ),
              if (quote.estimatedDurationDays != null)
                _MetaChip(
                  icon: Icons.schedule_outlined,
                  label: '~${quote.estimatedDurationDays} days',
                ),
              _MetaChip(
                icon: quote.materialsIncluded
                    ? Icons.inventory_2_outlined
                    : Icons.shopping_bag_outlined,
                label: quote.materialsIncluded
                    ? 'Materials included'
                    : 'Materials by you',
              ),
            ],
          ),
          SizedBox(height: Space.s4),
          if (isDecided)
            Text(
              isAccepted ? 'Accepted' : quote.status,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            FixoPrimaryButton(
              label: accepting ? 'Accepting…' : 'Accept quote',
              onPressed: accepting ? null : onAccept,
              isLoading: accepting,
            ),
        ],
      ),
    );
  }

  String _priceLine() {
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

  String _dateLabel(DateTime utc) {
    final local = utc.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class _DetailBlock extends StatelessWidget {
  final String label;
  final String text;

  const _DetailBlock({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: Space.s0_5),
        Text(text, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s1_5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.pill),
        color: DesignTokens.surfaceTonal(isDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: Sizes.iconSm,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: Space.s1_5),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
