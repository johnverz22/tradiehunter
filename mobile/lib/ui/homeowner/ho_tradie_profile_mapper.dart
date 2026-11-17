import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';

/// A truthful hero stat. Only values returned by the profile or the job's
/// Choose-a-Tradie row are included — never an invented experience figure.
class ThProfileStat {
  const ThProfileStat({required this.value, required this.label});

  final String value;
  final String label;
}

bool thHasRating(UserProfile? profile) {
  final count = profile?.reviewCount;
  final average = profile?.averageRating;
  return count != null && count > 0 && average != null && average > 0;
}

String thProfileName(UserProfile? profile) {
  final name = profile?.fullName.trim() ?? '';
  return name.isEmpty ? 'Name unavailable' : name;
}

String thProfileSubtitle(UserProfile? profile) {
  final business = profile?.businessName?.trim() ?? '';
  if (business.isNotEmpty) return business;
  final trade = profile?.tradeType?.trim() ?? '';
  return trade.isEmpty ? 'Tradie' : trade;
}

String? thProfileRegistration(UserProfile? profile) {
  final reg = profile?.registrationNumber?.trim() ?? '';
  return reg.isEmpty ? null : reg;
}

String thReviewCountLabel(int count) =>
    count == 1 ? '1 review' : '$count reviews';

String? thMemberSince(UserProfile? profile) {
  final since = profile?.memberSinceUtc;
  if (since == null) return null;
  return 'Member since ${DateFormat('MMMM yyyy').format(since.toLocal())}';
}

String? thProfileStatsLine({
  required UserProfile? profile,
  TradieListEntry? jobEntry,
}) {
  final parts = <String>[
    if (jobEntry?.completedJobs != null)
      '${jobEntry!.completedJobs} jobs completed',
    if (thProfileRegistration(profile) != null)
      'NZ Reg #${thProfileRegistration(profile)}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

List<ThProfileStat> thProfileStats({
  required UserProfile? profile,
  TradieListEntry? jobEntry,
}) {
  final stats = <ThProfileStat>[];
  if (thHasRating(profile)) {
    stats.add(
      ThProfileStat(
        value: profile!.averageRating!.toStringAsFixed(1),
        label: thReviewCountLabel(profile.reviewCount!),
      ),
    );
  }
  if (jobEntry?.completedJobs != null && jobEntry!.completedJobs! > 0) {
    stats.add(
      ThProfileStat(value: '${jobEntry.completedJobs}', label: 'Jobs done'),
    );
  }
  if (jobEntry != null && jobEntry.hasDistance) {
    stats.add(ThProfileStat(value: thDistanceValue(jobEntry), label: 'Away'));
  }
  if (stats.length < 3 && profile?.memberSinceUtc != null) {
    stats.add(
      ThProfileStat(
        value: DateFormat('yyyy').format(profile!.memberSinceUtc!.toLocal()),
        label: 'Member since',
      ),
    );
  }
  return stats;
}

String thDistanceValue(TradieListEntry entry) {
  final distance = entry.distance.trim();
  if (distance.isNotEmpty) {
    return distance.endsWith(' away')
        ? distance.substring(0, distance.length - ' away'.length)
        : distance;
  }
  return '${entry.distanceKm.toStringAsFixed(1)} km';
}

/// The job-scoped rate label, including the D8 GST suffix only when the server
/// returned a GST status. Null means the rate card is omitted.
String? thRateLabel(TradieListEntry? entry) {
  final rate = entry?.hourlyRate;
  if (rate == null) return null;
  final gst = gstLabelFor(entry!.isGstRegistered);
  return '${formatRate(rate)}${gst == null ? '' : ' · $gst'}';
}

bool thHasTrustDetails(UserProfile? profile) =>
    profile?.isVerified == true ||
    profile?.hasInsurance == true ||
    thProfileRegistration(profile) != null;

/// First completed job shared by the viewer and the viewed profile. Used to
/// open the real rating sheet; null means no review can be submitted yet.
Job? thCompletedSharedJob(
  List<Job> jobs, {
  required String viewerId,
  required String profileId,
}) {
  for (final job in jobs) {
    if (job.status != 'Completed') continue;
    final shared =
        (job.homeownerId == viewerId && job.matchedTradieId == profileId) ||
        (job.matchedTradieId == viewerId && job.homeownerId == profileId);
    if (shared) return job;
  }
  return null;
}

List<Job> thRequestableJobs(List<Job> jobs) =>
    jobs.where((job) => job.status == 'Requested').toList();
