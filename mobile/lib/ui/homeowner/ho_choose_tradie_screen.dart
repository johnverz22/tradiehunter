// ThChooseTradieScreen: v2 Choose-a-Tradie (migration plan 4.1 #4, id
// `ho_choose_tradie`, route `/jobs/:jobId/tradies`).
//
// Hand-owned port of views/jobs/tradie_list_screen.dart. Same data flow:
// tradieListProvider(jobId) loads on entry and on sort/filter changes (the
// server owns ranking); pull-to-refresh; loading / error / empty states;
// card tap opens the tradie profile in job context (route unchanged, plan
// 4.4); "Quick match for me" calls the same triggerMatch endpoint and pushes
// the matching screen, with the v1 warning notice when it cannot start.
//
// The mockup omits the verified/insured/available filters, but they are the
// only way to filter, so they stay as a second pill row (`needs-design`, gap
// G-7). The header subtitle comes from a one-shot job read and is omitted
// when that fails (gap G-6) — nothing is invented.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import '../feedback/th_state_view.dart';
import '../shared/th_choice_pills.dart';
import 'ho_choose_tradie_mapper.dart';
import 'ho_tradie_card.dart';

/// Job title/category for the app-bar subtitle. `null` means the read failed;
/// the subtitle is then omitted rather than guessed (gap G-6).
final chooseTradieJobProvider = FutureProvider.autoDispose.family<Job?, String>(
  (ref, jobId) => ref.watch(jobsRepositoryProvider).getJobById(jobId),
);

class ThChooseTradieScreen extends ConsumerStatefulWidget {
  const ThChooseTradieScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<ThChooseTradieScreen> createState() =>
      _ThChooseTradieScreenState();
}

class _ThChooseTradieScreenState extends ConsumerState<ThChooseTradieScreen> {
  bool _startingMatch = false;

  void _startQuickMatch() {
    if (_startingMatch) return;
    setState(() => _startingMatch = true);
    _runQuickMatch();
  }

  Future<void> _runQuickMatch() async {
    final started = await ref
        .read(jobsRepositoryProvider)
        .triggerMatch(widget.jobId);
    if (!mounted) return;
    setState(() => _startingMatch = false);
    if (started) {
      context.push('/jobs/${widget.jobId}/matching');
    } else {
      THNotice.warning(
        context,
        'Quick match could not start for this job — it may already be booked.',
      );
    }
  }

  void _onEmptyAction(TradieListState state, TradieListNotifier notifier) {
    switch (thChooseTradieEmptyAction(state)) {
      case ChooseTradieEmptyAction.clearFilters:
        if (state.verifiedOnly) notifier.toggleVerified();
        if (state.insuredOnly) notifier.toggleInsured();
        if (state.availableNowOnly) notifier.toggleAvailableNow();
      case ChooseTradieEmptyAction.reload:
        notifier.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tradieListProvider(widget.jobId));
    final notifier = ref.read(tradieListProvider(widget.jobId).notifier);
    final job = ref.watch(chooseTradieJobProvider(widget.jobId)).valueOrNull;
    final subtitle = thChooseTradieSubtitle(
      title: job?.title,
      category: job?.category,
    );

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          return Scaffold(
            key: const Key('choose_tradie'),
            backgroundColor: context.th.paper,
            appBar: THAppBar(title: 'Choose a Tradie', subtitle: subtitle),
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Sizes.gutter,
                      Space.s2,
                      Sizes.gutter,
                      0,
                    ),
                    child: ThChoicePills(
                      key: const Key('tradie_sort_bar'),
                      items: [
                        for (final sort in TradieListSort.values)
                          ThChoicePillItem(
                            label: thTradieSortLabel(sort),
                            selected: state.sort == sort,
                            icon: thTradieSortIcon(sort),
                            onSelected: () {
                              notifier.setSort(sort);
                            },
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Sizes.gutter,
                      Space.s2,
                      Sizes.gutter,
                      0,
                    ),
                    child: ThChoicePills(
                      items: [
                        ThChoicePillItem(
                          key: const Key('tradie_filter_verified'),
                          label: 'Verified',
                          selected: state.verifiedOnly,
                          onSelected: () {
                            notifier.toggleVerified();
                          },
                        ),
                        ThChoicePillItem(
                          key: const Key('tradie_filter_insured'),
                          label: 'Insured',
                          selected: state.insuredOnly,
                          onSelected: () {
                            notifier.toggleInsured();
                          },
                        ),
                        ThChoicePillItem(
                          key: const Key('tradie_filter_available'),
                          label: 'Available now',
                          selected: state.availableNowOnly,
                          onSelected: () {
                            notifier.toggleAvailableNow();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.s2),
                  Expanded(child: _body(context, state, notifier)),
                ],
              ),
            ),
            bottomNavigationBar: THStickyBar(
              children: [
                THButton(
                  key: const Key('quick_match_button'),
                  label: 'Quick match for me',
                  kind: THButtonKind.accent,
                  icon: Icons.bolt_rounded,
                  loading: _startingMatch || state.isLoading,
                  onPressed: _startingMatch ? null : _startQuickMatch,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    TradieListState state,
    TradieListNotifier notifier,
  ) {
    if (state.isLoading && state.tradies.isEmpty) {
      return const ThStateView.loading(label: 'Finding tradies…');
    }
    if (state.error != null && state.tradies.isEmpty) {
      return ThStateView.error(
        message: 'Could not load tradies for this job.',
        onRetry: () {
          notifier.load();
        },
      );
    }
    if (state.tradies.isEmpty) {
      return ThStateView.empty(
        key: const Key('tradie_empty'),
        icon: Icons.search_off_outlined,
        title: 'No tradies match yet',
        body:
            'Try removing a filter, or use Quick match '
            'to let us contact tradies for you.',
        actionLabel: 'Clear filters',
        onAction: () => _onEmptyAction(state, notifier),
      );
    }
    return RefreshIndicator(
      onRefresh: notifier.load,
      child: ListView.separated(
        key: const Key('tradie_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          Sizes.gutter,
          Space.s2,
          Sizes.gutter,
          Sizes.stickyClearance,
        ),
        itemCount: state.tradies.length,
        separatorBuilder: (_, _) => const SizedBox(height: Space.s4),
        itemBuilder: (context, index) {
          final entry = state.tradies[index];
          return HoTradieCard(
            key: ValueKey(entry.tradieId),
            entry: entry,
            onTap: () {
              context.push('/tradie/${entry.tradieId}?jobId=${widget.jobId}');
            },
          );
        },
      ),
    );
  }
}
