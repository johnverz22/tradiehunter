/// Tradie own-profile summary rows (plan 5.8, fix plan T-12): rating,
/// services / rates and credentials status. Pure label mappers plus the two
/// read providers; the rows themselves live in `profile_screen.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tradie_onboarding.dart';
import '../../utils/money.dart';
import '../../viewmodels/profile_viewmodel.dart';

/// `GET /api/tradie/rates` for the calling tradie.
final trProfileRatesProvider =
    FutureProvider.autoDispose<List<TradieRateEntry>>(
      (ref) => ref.watch(profileRepositoryProvider).getRates(),
    );

/// `GET /api/tradie/credentials` for the calling tradie.
final trProfileCredentialsProvider =
    FutureProvider.autoDispose<List<TradieCredential>>(
      (ref) => ref.watch(profileRepositoryProvider).getCredentials(),
    );

/// "4.8 · 12 reviews" from the profile DTO's server-computed aggregate.
/// No reviews → "No reviews yet" (never a 0.0 rating).
String trRatingLabel(Object? averageRating, Object? reviewCount) {
  final count = (reviewCount as num?)?.toInt() ?? 0;
  final avg = (averageRating as num?)?.toDouble() ?? 0;
  if (count <= 0 || avg <= 0) return 'No reviews yet';
  final reviews = count == 1 ? '1 review' : '$count reviews';
  return '${avg.toStringAsFixed(1)} · $reviews';
}

/// "3 services · $60.00–$95.00/hr", "1 service · $80.00/hr" or "Not set".
String trRatesSummary(List<TradieRateEntry> rates) {
  if (rates.isEmpty) return 'Not set';
  final values = [for (final r in rates) r.hourlyRate];
  var lo = values.first;
  var hi = values.first;
  for (final v in values) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  final services = rates.length == 1 ? '1 service' : '${rates.length} services';
  final range = lo == hi
      ? '${formatMoney(lo)}/hr'
      : '${formatMoney(lo)}–${formatMoney(hi)}/hr';
  return '$services · $range';
}

/// "2 approved · 1 pending · 1 rejected", skipping zero buckets;
/// "None uploaded" when empty. Status names match `CredentialStatus`.
String trCredentialsSummary(List<TradieCredential> credentials) {
  if (credentials.isEmpty) return 'None uploaded';
  int count(String status) =>
      credentials.where((c) => c.status == status).length;
  final parts = <String>[
    if (count('Approved') > 0) '${count('Approved')} approved',
    if (count('Pending') > 0) '${count('Pending')} pending',
    if (count('Rejected') > 0) '${count('Rejected')} rejected',
  ];
  return parts.isEmpty ? '${credentials.length} uploaded' : parts.join(' · ');
}

/// Label for an async summary while it loads or fails.
String trSummaryOr<T>(AsyncValue<T> value, String Function(T data) label) =>
    value.when(
      data: label,
      loading: () => 'Loading…',
      error: (_, _) => 'Unavailable',
    );
