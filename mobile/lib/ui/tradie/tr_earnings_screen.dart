// TrEarningsScreen: v2 tradie earnings screen (plan 5.6).
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_state_view.dart';

class TrEarningsScreen extends ConsumerStatefulWidget {
  const TrEarningsScreen({super.key});

  @override
  ConsumerState<TrEarningsScreen> createState() => _TrEarningsScreenState();
}

class _TrEarningsScreenState extends ConsumerState<TrEarningsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(tradieEarningsProvider.notifier).load();
    });
  }

  Future<void> _refresh() => ref.read(tradieEarningsProvider.notifier).load();

  @override
  Widget build(BuildContext context) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: Builder(builder: (ctx) => _page(ctx)),
  );

  Widget _page(BuildContext context) {
    final state = ref.watch(tradieEarningsProvider);
    final summary = state.summary;

    Widget body;
    if (state.isLoading && summary == null) {
      body = ThStateView.loading(label: 'Loading earnings...');
    } else if (state.error != null && summary == null) {
      body = ThStateView.error(
        message: state.error!,
        onRetry: () => ref.read(tradieEarningsProvider.notifier).load(),
      );
    } else if (summary == null) {
      body = ThStateView.empty(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No earnings yet',
        body: 'Completed jobs and payouts will appear here.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: _LoadedEarningsBody(summary: summary),
      );
    }

    return THScaffold(
      appBar: const THAppBar(title: 'Earnings'),
      dock: const THDock(role: THDockRole.tradie, active: THDockTab.profile),
      scrollable: summary == null,
      body: body,
    );
  }
}

class _LoadedEarningsBody extends StatelessWidget {
  const _LoadedEarningsBody({required this.summary});

  final TradieEarnings summary;

  String _amountOrMissing(Decimal? value) =>
      value != null ? formatMoney(value) : 'No figure yet';

  @override
  Widget build(BuildContext context) {
    final startLocal = summary.periodStartUtc.toLocal();
    final endLocal = summary.periodEndUtc.toLocal();
    final asOfLocal = summary.asOfUtc.toLocal();
    final periodLabel =
        '${DateFormat.MMMd().format(startLocal)} – ${DateFormat.MMMd().format(endLocal)} (${summary.timeZone})';
    final asOfLabel = 'As of ${DateFormat.MMMd().add_jm().format(asOfLocal)}';

    final failed = summary.failedNet;
    final showFailed = failed != null && failed > Decimal.zero;

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.s6),
      children: [
        THHero(
          children: [
            const THText(
              'NET THIS WEEK',
              style: THTextStyle.label,
              tone: THTone.gold,
            ),
            const SizedBox(height: Space.s1_5),
            THText(
              _amountOrMissing(summary.earnedNet),
              style: THTextStyle.moneyLg,
              tone: THTone.onHero,
            ),
            const SizedBox(height: Space.s1),
            THText(periodLabel, style: THTextStyle.meta, tone: THTone.onHeroSoft),
            THText(asOfLabel, style: THTextStyle.meta, tone: THTone.onHeroSoft),
          ],
        ),
        const SizedBox(height: Space.s3),
        THCard(
          padding: Space.s4,
          children: [
            THKeyValue(
              'Processed',
              _amountOrMissing(summary.processedNet),
              bold: true,
            ),
            THKeyValue(
              'Outstanding (all time)',
              _amountOrMissing(summary.pendingNet),
              bold: true,
              divider: true,
            ),
          ],
        ),
        if (showFailed) ...[
          const SizedBox(height: Space.s3),
          THCard(
            padding: Space.s4,
            children: [
              THKeyValue(
                'Failed payouts',
                formatMoney(failed),
                bold: true,
                strong: true,
              ),
              const SizedBox(height: Space.s2),
              const THText(
                'One or more payouts failed. Please check your bank details or contact support.',
                style: THTextStyle.meta,
                tone: THTone.soft,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
