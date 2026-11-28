// Pure display rules for the v2 Choose-a-Tradie screen (`ho_choose_tradie`,
// migration plan 4.1 #4).
//
// Ports the card copy and empty-state decision of
// views/jobs/tradie_list_screen.dart without importing it (lib/ui/** must not
// import v1). Money always goes through utils/money.dart; the D8 GST label is
// the shared `gstLabelFor` rule and is omitted when GST status is unknown.
import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';
import '../../viewmodels/jobs_viewmodel.dart' show TradieListSort;
import '../../viewmodels/jobs_viewmodel.dart' show TradieListState;

/// Header subtitle ("Leaking kitchen tap · Plumbing"). Null when neither the
/// job title nor its category is available — never invented (gap G-6).
String? thChooseTradieSubtitle({String? title, String? category}) {
  final t = title?.trim() ?? '';
  final c = category?.trim() ?? '';
  if (t.isEmpty) return c.isEmpty ? null : c;
  if (c.isEmpty) return t;
  return '$t · $c';
}

bool _hasRating(TradieListEntry e) =>
    e.rating != null && e.rating! > 0 && (e.reviewCount ?? 0) > 0;

/// Score part of the rating line ("4.9"), or null when the server sent no
/// usable rating. v1 only showed a rating when both score and count existed.
String? thTradieScore(TradieListEntry e) =>
    _hasRating(e) ? e.rating!.toStringAsFixed(1) : null;

/// Review-count part of the rating line ("(128)"), empty without a rating.
String thTradieReviewCount(TradieListEntry e) =>
    _hasRating(e) ? '(${e.reviewCount})' : '';

/// v1 fallback copy when there is no rating to show.
String thTradieNoRatingFallback(TradieListEntry e) => (e.completedJobs ?? 0) > 0
    ? '${e.completedJobs} jobs completed'
    : 'New to Fixo';

/// Distance line: server-rendered string first, then the numeric distance,
/// then the v1 "unavailable" copy. Never a fabricated zero.
String thTradieDistanceLine(TradieListEntry e) {
  final server = e.distance.trim();
  if (server.isNotEmpty) return server;
  if (e.distanceKm > 0) return '${e.distanceKm.toStringAsFixed(1)} km';
  return 'Distance unavailable';
}

/// Hourly rate + D8 GST note. Null when the server sent no rate, so the card
/// omits the amount entirely (never a fabricated $0).
({String amount, String? gstNote})? thTradieRate(TradieListEntry e) {
  final rate = e.hourlyRate;
  if (rate == null) return null;
  return (amount: formatMoney(rate), gstNote: gstLabelFor(e.isGstRegistered));
}

enum ThTradieBadgeKind { verified, insured, available }

class ThTradieBadge {
  const ThTradieBadge(this.label, this.kind, {this.icon, this.dot = false});

  final String label;
  final ThTradieBadgeKind kind;
  final IconData? icon;
  final bool dot;
}

/// Positive presence label for a tradie returned by the server (QA §1).
/// Returns null when presence is unknown — never fabricated.
String? thTradiePresenceLabel(TradieListEntry e, DateTime now) {
  if (!e.online) return null;
  final seen = e.lastSeenAtUtc;
  if (seen == null) return 'Online now';
  final mins = now.toUtc().difference(seen.toUtc()).inMinutes;
  if (mins < 2) return 'Online now';
  return 'Active $mins min ago';
}

/// Real server booleans only; no badge is shown for an unknown value.
List<ThTradieBadge> thTradieBadges(TradieListEntry e) => [
  if (e.verified)
    const ThTradieBadge(
      'Verified',
      ThTradieBadgeKind.verified,
      icon: Icons.verified_user_rounded,
    ),
  if (e.insured) const ThTradieBadge('Insured', ThTradieBadgeKind.insured),
  if (e.online || e.available)
    ThTradieBadge(
      thTradiePresenceLabel(e, DateTime.now()) ?? 'Available now',
      ThTradieBadgeKind.available,
      dot: true,
    ),
];

/// What the empty state's single action should do: clear the active filters,
/// or reload when no filter is active (same decision as v1).
enum ChooseTradieEmptyAction { clearFilters, reload }

ChooseTradieEmptyAction thChooseTradieEmptyAction(TradieListState state) =>
    state.verifiedOnly || state.insuredOnly || state.availableNowOnly
    ? ChooseTradieEmptyAction.clearFilters
    : ChooseTradieEmptyAction.reload;

/// Mockup pill labels: "Sort" is the server's best-match ranking.
String thTradieSortLabel(TradieListSort sort) => switch (sort) {
  TradieListSort.best => 'Sort',
  TradieListSort.rating => 'Rating',
  TradieListSort.distance => 'Distance',
  TradieListSort.rate => 'Rate',
};

IconData? thTradieSortIcon(TradieListSort sort) =>
    sort == TradieListSort.best ? Icons.tune_rounded : null;
