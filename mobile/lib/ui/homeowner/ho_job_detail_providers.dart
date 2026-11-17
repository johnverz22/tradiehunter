import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/jobs_viewmodel.dart';

class HoJobDetailData {
  const HoJobDetailData({
    required this.job,
    required this.tradie,
    required this.contact,
    required this.adjustments,
    this.hasReview = false,
  });

  final Job? job;
  final UserProfile? tradie;
  final JobContact? contact;
  final List<JobAdjustment> adjustments;
  final bool hasReview;
}

/// Loads only existing API data used by the v1 detail screen. Contact and
/// public-profile failures are optional, matching v1's non-blocking behavior.
final hoJobDetailProvider = FutureProvider.autoDispose
    .family<HoJobDetailData, String>((ref, jobId) async {
      final jobs = ref.watch(jobsRepositoryProvider);
      final job = await jobs.getJobById(jobId);
      if (job == null) {
        return HoJobDetailData(
          job: null,
          tradie: null,
          contact: null,
          adjustments: const [],
        );
      }

      UserProfile? tradie;
      JobContact? contact;
      final tradieId = job.matchedTradieId;
      if (tradieId != null && tradieId.isNotEmpty) {
        try {
          tradie = await ref
              .watch(reviewsRepositoryProvider)
              .getProfile(tradieId);
        } catch (_) {
          // Missing optional profile details never block job access.
        }
        try {
          contact = await jobs.getJobContact(jobId);
        } catch (_) {
          // Contact is optional; preserve the rest of the detail.
        }
      }

      final adjustments = await jobs.getAdjustments(jobId);
      return HoJobDetailData(
        job: job,
        tradie: tradie,
        contact: contact,
        adjustments: adjustments,
      );
    });
