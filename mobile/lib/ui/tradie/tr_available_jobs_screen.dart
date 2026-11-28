import 'package:decimal/decimal.dart';
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
import '../feedback/th_state_view.dart';
import '../homeowner/ho_quotes_screen.dart' show thQuotesCloseLabel;

String thBoardCloseBadge(DateTime closeAtUtc, {DateTime? nowUtc}) {
  final raw = thQuotesCloseLabel(closeAtUtc, nowUtc: nowUtc);
  if (raw == null) return '';
  if (raw == 'Quotes closed') return 'Closed';
  return raw.replaceFirst('Quotes close in ', 'Closes in ');
}

String thBoardBudgetLabel(Decimal? min, Decimal? max) {
  if (min != null && max != null) {
    return '${formatMoney(min)} – ${formatMoney(max)}';
  }
  if (min != null) return 'From ${formatMoney(min)}';
  if (max != null) return 'Up to ${formatMoney(max)}';
  return 'Not specified';
}

String thBoardMaterialsLabel(String materialsBy) => switch (materialsBy) {
  'Tradie' => 'Tradie supplies',
  'Homeowner' => 'Homeowner supplies',
  _ => 'Undecided',
};

String thBoardTimingLabel(String timingPreference) =>
    switch (timingPreference) {
      'Asap' => 'ASAP',
      'SpecificDate' => 'Specific date',
      'DateRange' => 'Date range',
      _ => 'Flexible',
    };

String thBoardQuotesCountLabel(int count) {
  if (count <= 0) return 'No quotes yet';
  return count == 1 ? '1 quote in' : '$count quotes in';
}

/// Tradie "Available jobs" board (plan 10 Q7.10, `tr_available_jobs`).
class TrAvailableJobsScreen extends ConsumerStatefulWidget {
  const TrAvailableJobsScreen({super.key});

  static const String route = '/tradie/available-jobs';

  @override
  ConsumerState<TrAvailableJobsScreen> createState() =>
      _TrAvailableJobsScreenState();
}

class _TrAvailableJobsScreenState extends ConsumerState<TrAvailableJobsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(availableJobsProvider.notifier).load();
    });
  }

  Future<void> _reload() => ref.read(availableJobsProvider.notifier).load();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(availableJobsProvider);
    final jobs = state.jobs;

    final Widget body;
    if (state.isLoading && jobs.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.error != null && jobs.isEmpty) {
      body = ThStateView.error(message: state.error!, onRetry: _reload);
    } else if (jobs.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Space.s4),
          children: const [
            THCard(
              children: [
                THText(
                  'No open projects nearby',
                  style: THTextStyle.title,
                  align: TextAlign.center,
                ),
                SizedBox(height: Space.s2),
                THText(
                  'When homeowners post projects matching your services and area, they will appear here.',
                  style: THTextStyle.body,
                  tone: THTone.soft,
                  align: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _reload,
        child: ListView.separated(
          padding: const EdgeInsets.all(Space.s1),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: jobs.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: Space.s3),
          itemBuilder: (context, index) {
            if (index == 0) {
              return THCard(
                tone: THCardTone.accent,
                padding: Space.s3_5,
                children: const [
                  THText(
                    'Projects posted by homeowners looking for quotes. Exact street addresses stay hidden until booked.',
                    style: THTextStyle.meta,
                    tone: THTone.soft,
                  ),
                ],
              );
            }
            final job = jobs[index - 1];
            return _AvailableJobCard(
              job: job,
              primary: index == 1,
              onOpen: () =>
                  context.push('/tradie/available-jobs/${job.id}', extra: job),
            );
          },
        ),
      );
    }

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: THScaffold(
        key: const Key('tr_available_jobs_screen'),
        appBar: const THAppBar(
          title: 'Available jobs',
          subtitle: 'Open projects near you',
        ),
        scrollable: false,
        body: body,
      ),
    );
  }
}

class _AvailableJobCard extends StatelessWidget {
  const _AvailableJobCard({
    required this.job,
    required this.primary,
    required this.onOpen,
  });

  final AvailableJob job;
  final bool primary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final suburb = job.suburb?.trim().isNotEmpty == true
        ? job.suburb!.trim()
        : 'Nearby';
    final dist = job.distanceKm != null
        ? '${job.distanceKm!.toStringAsFixed(1)} km'
        : null;
    final metaParts = [
      suburb,
      ?dist,
      thBoardQuotesCountLabel(job.quotesReceived),
    ];

    return THCard(
      key: Key('available_job_card_${job.id}'),
      padding: Space.s4,
      children: [
        Wrap(
          spacing: Space.s1_5,
          runSpacing: Space.s1_5,
          children: [
            THBadge(job.category, kind: THBadgeKind.brand),
            THBadge(
              thBoardCloseBadge(job.quotesCloseAtUtc),
              kind: THBadgeKind.accent,
              icon: Icons.schedule_rounded,
            ),
          ],
        ),
        const SizedBox(height: Space.s2),
        THText(job.title, style: THTextStyle.title),
        const SizedBox(height: Space.s1),
        THText(
          metaParts.join(' · '),
          style: THTextStyle.meta,
          tone: THTone.soft,
        ),
        const SizedBox(height: Space.s2),
        THKeyValue(
          'Budget',
          thBoardBudgetLabel(job.budgetMin, job.budgetMax),
          bold: true,
        ),
        THKeyValue(
          'Materials',
          thBoardMaterialsLabel(job.materialsBy),
          bold: true,
          divider: true,
        ),
        THKeyValue(
          'Timing',
          thBoardTimingLabel(job.timingPreference),
          bold: true,
          divider: true,
        ),
        const SizedBox(height: Space.s3),
        THButton(
          key: Key('view_board_job_${job.id}'),
          label: 'View details & quote',
          kind: primary ? THButtonKind.accent : THButtonKind.secondary,
          size: THButtonSize.sm,
          onPressed: onOpen,
        ),
      ],
    );
  }
}
