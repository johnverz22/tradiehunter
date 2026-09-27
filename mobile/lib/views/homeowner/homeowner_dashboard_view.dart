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

/// Mockup 05-homeowner-home, restyled.
///
/// NOTE ON MVVM: the provided archive has no dedicated
/// `HomeownerViewModel` — this screen (like the original
/// `homeowner_home_screen.dart`) reads `jobsViewModelProvider` and
/// `profileViewModelProvider` directly. Every provider read, notifier
/// call, SignalR subscription and state variable below is copied
/// unchanged from the original file; only the widget tree changed.
/// Class kept as `HomeownerHomeScreen` so existing router imports keep
/// working if you replace the old file's contents with this one.
class HomeownerHomeScreen extends ConsumerStatefulWidget {
  const HomeownerHomeScreen({super.key});

  @override
  ConsumerState<HomeownerHomeScreen> createState() => _HomeownerHomeScreenState();
}

class _HomeownerHomeScreenState extends ConsumerState<HomeownerHomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs());
    _initSignalR();
  }

  Future<void> _initSignalR() async {
    final hub = ref.read(jobHubClientProvider);
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5000');

    await hub.connect(baseUrl: baseUrl);

    hub.onJobStatusChanged.listen((e) {
      ref.read(jobsViewModelProvider.notifier).applyStatusUpdate(e.jobId, e.status);
    });
  }

  FixoBadgeKind _kindFor(String status) {
    return status == 'Matched' || status == 'Confirmed' || status == 'Complete'
        ? FixoBadgeKind.verified
        : FixoBadgeKind.hold;
  }

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobsViewModelProvider);
    final profileState = ref.watch(profileViewModelProvider);
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final firstName = profileState.profile?['firstName'] as String? ?? '';
    final lastName = profileState.profile?['lastName'] as String? ?? '';
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
        .toUpperCase();
    final greeting = firstName.isNotEmpty ? 'Hey $firstName,' : 'Hey there,';

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const FixoWordmark(fontSize: 22),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FixoAvatar(initials: initials.isNotEmpty ? initials : '?'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: jobsState.isLoading && jobsState.jobs.isEmpty
            ? const FixoLoading(label: 'Loading your jobs...')
            : jobsState.error != null && jobsState.jobs.isEmpty
                ? FixoErrorState(
                    message: jobsState.error!,
                    onRetry: () => ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs(),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs(),
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(24, 8, 24, 120 + bottomPadding),
                      children: [
                        Text(
                          greeting,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Here's what's happening with your jobs.",
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 20),
                        if (jobsState.jobs.isEmpty)
                          FixoEmptyState(
                            icon: Icons.home_repair_service_outlined,
                            title: 'No active jobs right now.',
                            subtitle: "Post a job and we'll match you in minutes.",
                            actionLabel: 'Post a Job',
                            onAction: () => context.push('/jobs/new'),
                          ),
                        for (final job in jobsState.jobs) ...[
                          ModernJobCard(
                            title: job.title,
                            referenceId: job.id,
                            category: job.category,
                            location: job.suburb,
                            statusLabel: job.status,
                            statusKind: _kindFor(job.status),
                            stage: job.stage,
                            onTap: () => context.push('/chat/${job.id}'),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/jobs/new'),
        backgroundColor: DesignTokens.amber,
        foregroundColor: DesignTokens.onAmber,
        icon: const Icon(Icons.add),
        label: const Text('Post a Job', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
