import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../../widgets/fixo_states.dart';
import '../../widgets/tradie_widgets.dart';
import '../widgets/modern_job_card.dart';

/// Mockup 09-tradie-home, restyled.
///
/// NOTE ON MVVM: as with the homeowner screen, there is no dedicated
/// `TradieViewModel` in the provided archive — this reads the same
/// `jobsViewModelProvider` / `profileViewModelProvider` the original
/// `tradie_home_screen.dart` used. The `_online` toggle stays local
/// `State` exactly as before (marked `TODO(backend)` in the original —
/// left untouched here), and both SignalR subscriptions
/// (`onNewJobMatch`, `onJobStatusChanged`) are preserved verbatim,
/// including cancellation in `dispose()`. Class kept as
/// `TradieHomeScreen` so existing router imports keep working if you
/// replace the old file's contents with this one.
class TradieHomeScreen extends ConsumerStatefulWidget {
  const TradieHomeScreen({super.key});

  @override
  ConsumerState<TradieHomeScreen> createState() => _TradieHomeScreenState();
}

class _TradieHomeScreenState extends ConsumerState<TradieHomeScreen> {
  // TODO(backend): PATCH /api/tradies/me/availability {online}.
  bool _online = true;

  StreamSubscription? _matchSub;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(jobsViewModelProvider.notifier).loadTradieJobs();
      _initSignalR();
    });
  }

  Future<void> _initSignalR() async {
    final hub = ref.read(jobHubClientProvider);
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5000');
    await hub.connect(baseUrl: baseUrl);

    _matchSub = hub.onNewJobMatch.listen((event) {
      if (mounted) {
        ref.read(jobsViewModelProvider.notifier).loadTradieJobs();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New Job Request: ${event.title}')),
        );
      }
    });

    _statusSub = hub.onJobStatusChanged.listen((e) {
      ref.read(jobsViewModelProvider.notifier).applyStatusUpdate(e.jobId, e.status);
    });
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  String _relativeTime(DateTime? dt) {
    if (dt == null) return 'recently';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobsViewModelProvider);
    final profileState = ref.watch(profileViewModelProvider);
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final firstName = profileState.profile?['firstName'] as String? ?? '';
    final greeting = firstName.isNotEmpty ? 'Hey $firstName,' : 'Hey there,';

    final jobCount = (profileState.profile?['jobCount'] as num?)?.toString() ?? '--';
    final rating = (profileState.profile?['averageRating'] as num?)?.toStringAsFixed(1) ?? '--';
    final responseRate = (profileState.profile?['responseRate'] as num?) != null
        ? '${profileState.profile!['responseRate']}%'
        : '--';

    final requested = jobsState.jobs.where((j) => j.status == 'Requested').toList();
    final active = jobsState.jobs.where((j) => j.status != 'Requested').toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const FixoWordmark(fontSize: 22),
        actions: [
          Row(
            children: [
              Text(
                'Online',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _online ? DesignTokens.green : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 44,
                  height: 24,
                  child: Switch(
                    value: _online,
                    activeThumbColor: Colors.white,
                    activeTrackColor: DesignTokens.green,
                    onChanged: (v) => setState(() => _online = v),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: jobsState.isLoading && jobsState.jobs.isEmpty
          ? const FixoLoading(label: 'Loading your jobs...')
          : jobsState.error != null && jobsState.jobs.isEmpty
              ? FixoErrorState(
                  message: jobsState.error!,
                  onRetry: () => ref.read(jobsViewModelProvider.notifier).loadTradieJobs(),
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 32 + bottomPadding),
                  children: [
                    Text(
                      greeting,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Here's your day at a glance.",
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          StatCard(value: jobCount, label: 'Jobs'),
                          const SizedBox(width: 12),
                          StatCard(value: rating, label: 'Rating'),
                          const SizedBox(width: 12),
                          StatCard(value: responseRate, label: 'Response'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Incoming Requests',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    if (requested.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'No incoming requests right now.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    for (final job in requested) ...[
                      ModernJobCard(
                        title: job.title,
                        category: job.category,
                        location: job.suburb,
                        statusLabel: 'Requested',
                        statusKind: FixoBadgeKind.hold,
                        isUrgent: job.urgency == 'Urgent',
                        timestampLabel: 'Requested ${_relativeTime(job.createdAtUtc)}',
                        onTap: () => context.push('/tradie/requests/${job.id}'),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Active Jobs',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    if (active.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'No active jobs right now.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    for (final job in active) ...[
                      ModernJobCard(
                        title: job.title,
                        category: job.category,
                        location: job.suburb,
                        statusLabel: job.status,
                        statusKind:
                            job.status == 'Matched' || job.status == 'Confirmed' || job.status == 'Complete'
                                ? FixoBadgeKind.verified
                                : FixoBadgeKind.neutral,
                        onTap: () => context.push('/chat/${job.id}'),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
    );
  }
}
