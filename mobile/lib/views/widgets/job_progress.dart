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
  final VoidCallback? onRefresh;
  final Map<int, DateTime>? stepDates;
  final bool initialExpanded;

  const JobProgress({
    super.key,
    required this.status,
    this.onRefresh,
    this.stepDates,
    this.initialExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return JobTimeline(
      key: ValueKey(status),
      status: status,
      onRefresh: onRefresh,
      stepDates: stepDates,
      initialExpanded: initialExpanded,
    );
  }
}
