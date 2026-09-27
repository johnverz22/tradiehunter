import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';

/// Mockup 07-matching: radar ripple + "Finding tradies near you…".
/// Triggers POST /api/jobs/:id/match and listens for SignalR match notifications.
class MatchingScreen extends ConsumerStatefulWidget {
  final String jobId;
  const MatchingScreen({super.key, required this.jobId});

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  StreamSubscription? _sub;
  bool _timeout = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();

    Future.microtask(_initMatching);
  }

  Future<void> _initMatching() async {
    final hub = ref.read(jobHubClientProvider);
    final repo = ref.read(jobsRepositoryProvider);

    // API_BASE_URL via --dart-define-from-file (default to emulator).
    const baseUrl = String.fromEnvironment('API_BASE_URL',
        defaultValue: 'http://localhost:5000');

    await hub.connect(baseUrl: baseUrl);
    await hub.joinJobGroup(widget.jobId);

    _sub = hub.onJobStatusChanged.listen((event) {
      if (event.jobId == widget.jobId && event.status == 'Matched') {
        _timer?.cancel();
        if (mounted) {
          context.pushReplacement('/jobs/${widget.jobId}/match');
        }
      }
    });

    // 30 second timeout if no match is found
    _timer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() => _timeout = true);
      }
    });

    // Trigger the backend matching process
    final matches = await repo.triggerMatch(widget.jobId);
    if (matches.isNotEmpty) {
      // Sometimes the SignalR event beats the HTTP response, or vice versa.
      // If we got matches back, we can just transition.
      _timer?.cancel();
      if (mounted) {
        context.pushReplacement('/jobs/${widget.jobId}/match');
      }
    } else {
      // Backend returned empty list -> no tradies available.
      _timer?.cancel();
      if (mounted) {
        setState(() => _timeout = true);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            if (!_timeout) ...[
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) => Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 120 + (((_ctrl.value + i / 3) % 1) * 120),
                        height: 120 + (((_ctrl.value + i / 3) % 1) * 120),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: DesignTokens.brand500.withValues(
                                alpha: 0.5 *
                                    (1 - ((_ctrl.value + i / 3) % 1))),
                            width: 2,
                          ),
                        ),
                      ),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DesignTokens.brand500,
                      ),
                      child: const Icon(Icons.search,
                          size: 48, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Text('Finding tradies near you…',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ] else ...[
              Icon(Icons.search_off, size: 80, color: theme.colorScheme.error),
              const SizedBox(height: 24),
              Text('No Tradies Available',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('We couldn\'t find a match right now. Please try again later.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
            const Spacer(flex: 2),
            TextButton(
              onPressed: () {
                // TODO(backend): DELETE /api/jobs/:id to cancel job if needed.
                context.pop();
              },
              child: Text(_timeout ? 'Go Back' : 'Cancel'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
