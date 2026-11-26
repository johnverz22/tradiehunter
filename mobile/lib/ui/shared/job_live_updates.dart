import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marketplace.dart' show Job;
import '../../repositories/job_hub_client.dart';
import '../../viewmodels/auth_viewmodel.dart' show resolveBaseUrl;
import '../../viewmodels/jobs_viewmodel.dart' show jobHubClientProvider;

/// Keeps a screen live for one job.
///
/// `JobStatusChanged` is only sent to the SignalR `job-{id}` group, so a screen
/// that listens to the hub without joining that group never hears anything.
/// This mixin owns the whole lifecycle in one place:
///
///  * connects the hub (a deep link can land here before any home screen did),
///  * joins the job group, ref-counted and re-joined on reconnect by
///    [JobHubClient.watchJob],
///  * calls [onJobLiveUpdate] for status / adjustment events for this job,
///    after every reconnect and when the app returns to the foreground (events
///    may have been missed while the socket was down or suspended),
///  * leaves the group and cancels subscriptions in `dispose`.
///
/// Call [startJobLiveUpdates] from `initState`.
mixin JobLiveUpdates<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// The job this screen is showing.
  String get liveJobId;

  /// Re-read server state. Called on the main isolate only while mounted.
  void onJobLiveUpdate();

  /// Whether adjustment events should also trigger [onJobLiveUpdate].
  bool get liveIncludesAdjustments => true;

  late final JobHubClient _liveHub;
  late final _ResumeObserver _liveResume = _ResumeObserver(_fire);
  final List<StreamSubscription<Object?>> _liveSubs = [];
  bool _liveWatching = false;

  void startJobLiveUpdates() {
    _liveHub = ref.read(jobHubClientProvider);
    final id = liveJobId;

    _liveSubs.add(
      _liveHub.onJobStatusChanged.listen((e) {
        if (e.jobId == id) _fire();
      }),
    );
    if (liveIncludesAdjustments) {
      _liveSubs.add(
        _liveHub.onAdjustmentChanged.listen((e) {
          if (e.jobId == id) _fire();
        }),
      );
    }
    _liveSubs.add(_liveHub.onReconnected.listen((_) => _fire()));
    WidgetsBinding.instance.addObserver(_liveResume);

    // Register interest first so the join happens as soon as the connection
    // is up, even if connecting fails now and succeeds on a later retry.
    _liveWatching = true;
    unawaited(_liveHub.watchJob(id));
    unawaited(_connectLive());
  }

  Future<void> _connectLive() async {
    try {
      await _liveHub.connect(baseUrl: resolveBaseUrl());
    } catch (e) {
      // Live updates are best-effort; the screen still works from its load.
      debugPrint('JobLiveUpdates connect failed for $liveJobId: $e');
    }
  }

  void _fire() {
    if (mounted) onJobLiveUpdate();
  }

  @override
  void dispose() {
    for (final sub in _liveSubs) {
      sub.cancel();
    }
    _liveSubs.clear();
    WidgetsBinding.instance.removeObserver(_liveResume);
    if (_liveWatching) {
      _liveWatching = false;
      unawaited(_liveHub.unwatchJob(liveJobId));
    }
    super.dispose();
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this._onResume);

  final VoidCallback _onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResume();
  }
}

/// Statuses after which a job can no longer change, so a list screen has no
/// reason to keep its hub group joined.
const _closedJobStatuses = {'Completed', 'Cancelled', 'Expired'};

/// Ids of the still-changing jobs in [jobs], for
/// [JobHubClient.setWatchedJobs].
Set<String> liveJobIds(Iterable<Job> jobs) => {
  for (final job in jobs)
    if (!_closedJobStatuses.contains(job.status)) job.id.toString(),
};
