import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/fixo_cards.dart';
import '../../widgets/fixo_states.dart';

/// Jobs tab — role-aware:
/// - Homeowner: their posted jobs + "Post a Job" FAB.
/// - Tradie: their assigned/active jobs, no post action.
class JobsListScreen extends ConsumerStatefulWidget {
  const JobsListScreen({super.key});

  @override
  ConsumerState<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends ConsumerState<JobsListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final isTradie =
          ref.read(profileViewModelProvider).profile?['role'] == 1;
      if (isTradie) {
        ref.read(jobsViewModelProvider.notifier).loadTradieJobs();
      } else {
        ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs();
      }
    });
  }

  FixoBadgeKind _kindFor(String status) {
    switch (status.toLowerCase()) {
      case 'matched':
      case 'confirmed':
      case 'complete':
        return FixoBadgeKind.verified;
      case 'urgent':
        return FixoBadgeKind.urgent;
      default:
        return FixoBadgeKind.hold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobsViewModelProvider);
    final profileState = ref.watch(profileViewModelProvider);
    final theme = Theme.of(context);

    final isTradie = profileState.profile?['role'] == 1;

    void retry() {
      if (isTradie) {
        ref.read(jobsViewModelProvider.notifier).loadTradieJobs();
      } else {
        ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs();
      }
    }

    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(isTradie ? 'My Jobs' : 'Jobs')),
      body: state.isLoading && state.jobs.isEmpty
          ? const FixoLoading(label: 'Loading jobs...')
          : state.error != null && state.jobs.isEmpty
              ? FixoErrorState(message: state.error!, onRetry: retry)
              : state.jobs.isEmpty
                  ? isTradie
                      ? const FixoEmptyState(
                          icon: Icons.work_off_outlined,
                          title: 'No jobs assigned yet',
                          subtitle:
                              'Accept an incoming request to get started.',
                        )
                      : FixoEmptyState(
                          icon: Icons.work_off_outlined,
                          title: 'No jobs yet',
                          subtitle: 'Post your first job to get matched.',
                          actionLabel: 'Post a Job',
                          onAction: () => context.push('/jobs/new'),
                        )
                  : RefreshIndicator(
                      onRefresh: () async => retry(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                        itemCount: state.jobs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final job = state.jobs[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(
                                DesignTokens.radius),
                            onTap: () => isTradie
                                ? context.push('/tradie/requests/${job.id}')
                                : context.push('/chat/${job.id}'),
                            child: FixoCard(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(job.title,
                                            style: theme
                                                .textTheme.titleMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                      ),
                                      StatusBadge(
                                        label: job.status,
                                        kind: _kindFor(job.status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${job.category} · ${job.suburb}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      // Only homeowners get the "Post a Job" FAB.
      floatingActionButton: isTradie
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/jobs/new'),
              backgroundColor: DesignTokens.amber,
              foregroundColor: DesignTokens.onAmber,
              icon: const Icon(Icons.add),
              label: const Text('Post a Job',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
    );
  }
}
