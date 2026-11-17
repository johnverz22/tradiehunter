import '../../models/marketplace.dart';

enum HoJobDetailView {
  booked,
  inProgress,
  extraCost,
  reviewCompletion,
  review,
  fallback,
}

enum HoJobDetailFallback { cancelled, dispute, unsupportedStatus }

class HoJobDetailSelection {
  const HoJobDetailSelection(this.view, {this.fallback});

  final HoJobDetailView view;
  final HoJobDetailFallback? fallback;
}

/// Total selector for the v2 detail states. Unsupported/no-design states remain
/// on the injected v1 screen until their 4.3 compositions are ready.
HoJobDetailSelection thSelectJobDetailView(
  Job job, {
  required List<JobAdjustment> adjustments,
  required bool hasReview,
  required bool hasTradie,
}) {
  if (job.status == 'Completed') {
    return const HoJobDetailSelection(HoJobDetailView.review);
  }
  if (job.status == 'Cancelled') {
    return const HoJobDetailSelection(
      HoJobDetailView.fallback,
      fallback: HoJobDetailFallback.cancelled,
    );
  }
  if (job.status == 'Disputed' ||
      job.disputeStatus == 'Open' ||
      job.disputeStatus == 'UnderReview') {
    return const HoJobDetailSelection(
      HoJobDetailView.fallback,
      fallback: HoJobDetailFallback.dispute,
    );
  }
  if (job.status == 'AwaitingConfirmation') {
    return const HoJobDetailSelection(HoJobDetailView.reviewCompletion);
  }
  if (job.status == 'InProgress' || job.status == 'Booked') {
    final hasPendingAdjustment = adjustments.any((item) => item.isPending);
    if (hasPendingAdjustment) {
      return const HoJobDetailSelection(HoJobDetailView.extraCost);
    }
    return HoJobDetailSelection(
      job.status == 'InProgress'
          ? HoJobDetailView.inProgress
          : HoJobDetailView.booked,
    );
  }
  return const HoJobDetailSelection(
    HoJobDetailView.fallback,
    fallback: HoJobDetailFallback.unsupportedStatus,
  );
}
