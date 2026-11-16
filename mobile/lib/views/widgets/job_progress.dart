import 'package:flutter/material.dart';

import 'compact_progress_bar.dart';
import 'job_timeline.dart';

export 'compact_progress_bar.dart';
export 'job_timeline.dart';

/// Legacy alias / wrapper around [JobTimeline] for detail pages.
///
/// For cards and list views, prefer [CompactProgressBar].
class JobProgress extends StatelessWidget {
  final String status;

  /// v1.7 (contract #6): the JobDto stage (0..5) under the job's
  /// [flowVersion]. Null falls back to the legacy status mapping.
  final int? stage;
  final int? flowVersion;
  final VoidCallback? onRefresh;
  final Map<int, DateTime>? stepDates;
  final bool initialExpanded;

  const JobProgress({
    super.key,
    required this.status,
    this.stage,
    this.flowVersion,
    this.onRefresh,
    this.stepDates,
    this.initialExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return JobTimeline(
      key: ValueKey('$status-$stage-$flowVersion'),
      status: status,
      stage: stage,
      flowVersion: flowVersion,
      onRefresh: onRefresh,
      stepDates: stepDates,
      initialExpanded: initialExpanded,
    );
  }
}
