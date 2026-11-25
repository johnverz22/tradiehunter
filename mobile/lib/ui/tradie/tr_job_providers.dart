// Shared loader for the v2 tradie job detail (plan 5.3). Same calls as the v1
// screen's `_load()`: job, then the homeowner contact only for contactable
// statuses (a failure hides the card, never fabricates one), then the
// extra-cost list. Review state is not loaded: v1 only tracks it in-session
// after a rating is submitted, so it stays screen state in later PRs.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import 'tr_job_state.dart';

class TrJobDetailData {
  const TrJobDetailData({
    required this.job,
    required this.contact,
    required this.adjustments,
  });

  /// Null when the job no longer exists for this tradie.
  final Job? job;
  final JobContact? contact;
  final List<JobAdjustment> adjustments;
}

final trJobDetailProvider = FutureProvider.autoDispose
    .family<TrJobDetailData, String>((ref, jobId) async {
      final repo = ref.watch(jobsRepositoryProvider);
      final job = await repo.getJobById(jobId);
      if (job == null) {
        return const TrJobDetailData(
          job: null,
          contact: null,
          adjustments: <JobAdjustment>[],
        );
      }

      JobContact? contact;
      if (trIsContactable(job.status)) {
        try {
          contact = await repo.getJobContact(jobId);
        } catch (_) {
          // Contact is optional; the rest of the detail still loads.
        }
      }

      final adjustments = await repo.getAdjustments(jobId);
      return TrJobDetailData(
        job: job,
        contact: contact,
        adjustments: adjustments,
      );
    });
