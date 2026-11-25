// Pure rules for the v2 tradie request detail (`tr_lead`, plan 5.2). No
// widgets: everything here is unit-tested and copied from the v1 behaviour
// of views/tradie/request_detail_screen.dart.
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';

/// Pricing models a quote can use (contract #12 wire values) with labels.
const trQuotePricingOptions = <(String, String)>[
  (Quote.pricingFixed, 'Fixed price'),
  (Quote.pricingEstimateRange, 'Estimate range'),
  (Quote.pricingHourlyWithCap, 'Hourly with cap'),
];

/// Backend-relative photo paths (`/api/photos/...`) become absolute URLs.
String trResolvePhotoUrl(String url, String baseUrl) =>
    url.startsWith('http') ? url : '$baseUrl$url';

/// Exact address is masked for tradies until Booked (v1 P5-01): the suburb is
/// the truthful location at offer time.
String trLocationLabel(Job job) =>
    job.suburb.isNotEmpty ? job.suburb : (job.address ?? 'Location on file');

/// Large total, or an em dash when the job has no total (never a fake zero).
String trPriceTotal(Job job) =>
    job.totalAmount != null ? formatMoney(job.totalAmount!) : '—';

/// `3 h × $85.00/h`, `3h`, or null when no hours are set (v1 `_PriceBlock`).
String? trPriceBreakdown(Job job) {
  final rate = job.hourlyRate;
  if (job.hours <= 0) return null;
  return rate != null ? '${job.hours} h × ${formatRate(rate)}' : '${job.hours}h';
}

/// `Monday 24 November · 9:30 am · 3h` in local time, or null when the job
/// has no scheduled start (v1 `_ScheduleCard`).
String? trScheduleLabel(Job job) {
  final start = job.scheduledStartUtc;
  if (start == null) return null;
  var text = DateFormat('EEEE d MMMM · h:mm a').format(start.toLocal());
  if (job.hours > 0) text += ' · ${job.hours}h';
  return text;
}

/// `Received 2 min ago`, derived from the offer (plan G-16). Null when the
/// offer is unknown.
String? trReceivedLabel(JobOffer? offer, DateTime now) {
  if (offer == null) return null;
  final age = now.toUtc().difference(offer.offeredAtUtc.toUtc());
  if (age.inSeconds < 60) return 'Received just now';
  if (age.inMinutes < 60) return 'Received ${age.inMinutes} min ago';
  if (age.inHours < 24) {
    final h = age.inHours;
    return 'Received $h h ago';
  }
  return 'Received ${age.inDays} d ago';
}

/// App-bar subtitle: received time and job reference, only real fields.
String? trLeadSubtitle(Job job, JobOffer? offer, DateTime now) {
  final parts = <String>[
    ?trReceivedLabel(offer, now),
    if (job.referenceCode != null && job.referenceCode!.isNotEmpty)
      'Job #${job.referenceCode}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Which bottom-bar variant the offer calls for.
enum TrLeadBar { gone, expired, accept, quote }

TrLeadBar trLeadBar(JobOffer? offer, {DateTime Function()? clock}) {
  if (offer == null) return TrLeadBar.gone;
  if (offer.remaining(clock?.call()).isNegative) return TrLeadBar.expired;
  return offer.isQuoteRequest ? TrLeadBar.quote : TrLeadBar.accept;
}

/// Copy under the bar when there is nothing to respond to.
String trLeadBarMessage(TrLeadBar bar) => bar == TrLeadBar.expired
    ? 'This offer has expired.'
    : 'This offer is no longer available.';

/// Raw quote-form values, as typed.
class TrQuoteDraft {
  const TrQuoteDraft({
    this.pricingModel = Quote.pricingFixed,
    this.amount = '',
    this.min = '',
    this.max = '',
    this.rate = '',
    this.cap = '',
    this.inclusions = '',
    this.exclusions = '',
    this.duration = '',
    this.materialsIncluded = false,
    this.gstIncluded = false,
    this.proposedStart,
  });

  final String pricingModel;
  final String amount;
  final String min;
  final String max;
  final String rate;
  final String cap;
  final String inclusions;
  final String exclusions;
  final String duration;
  final bool materialsIncluded;
  final bool gstIncluded;
  final DateTime? proposedStart;

  Decimal? _money(String text) {
    final parsed = Decimal.tryParse(text.trim());
    return parsed != null && parsed > Decimal.zero ? parsed : null;
  }

  Decimal? get fixedAmount => _money(amount);
  Decimal? get rangeMin => _money(min);
  Decimal? get rangeMax => _money(max);
  Decimal? get hourlyRate => _money(rate);
  Decimal? get hourlyCap => _money(cap);

  int? get durationDays {
    final parsed = int.tryParse(duration.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  /// Estimate range with both bounds set and min above max.
  bool get rangeInverted =>
      rangeMin != null && rangeMax != null && rangeMin! > rangeMax!;

  bool get canSubmit => switch (pricingModel) {
    Quote.pricingFixed => fixedAmount != null,
    Quote.pricingEstimateRange =>
      rangeMin != null && rangeMax != null && rangeMin! <= rangeMax!,
    Quote.pricingHourlyWithCap => hourlyRate != null && hourlyCap != null,
    _ => false,
  };

  /// The POST /api/jobs/:id/quotes body, or null while the form is invalid.
  /// Keys and omission rules are the v1 `_QuoteFormSheet._submit` ones.
  Map<String, dynamic>? toPayload() {
    if (!canSubmit) return null;
    final inc = inclusions.trim();
    final exc = exclusions.trim();
    return {
      'pricingModel': pricingModel,
      if (pricingModel == Quote.pricingFixed && fixedAmount != null)
        'amount': fixedAmount.toString(),
      if (pricingModel == Quote.pricingEstimateRange && rangeMin != null)
        'minAmount': rangeMin.toString(),
      if (pricingModel == Quote.pricingEstimateRange && rangeMax != null)
        'maxAmount': rangeMax.toString(),
      if (pricingModel == Quote.pricingHourlyWithCap && hourlyRate != null)
        'amount': hourlyRate.toString(),
      if (pricingModel == Quote.pricingHourlyWithCap && hourlyCap != null)
        'cap': hourlyCap.toString(),
      if (inc.isNotEmpty) 'inclusions': inc,
      if (exc.isNotEmpty) 'exclusions': exc,
      'materialsIncluded': materialsIncluded,
      'gstIncluded': gstIncluded,
      if (proposedStart != null)
        'proposedStartUtc': proposedStart!.toUtc().toIso8601String(),
      if (durationDays != null) 'estimatedDurationDays': durationDays,
    };
  }
}

/// Helper copy under the GST switch (v1 wording).
String trGstHelper({required bool? fromProfile, required bool included}) {
  if (fromProfile == null) {
    return 'Tick only if you are GST-registered — the app validates this '
        'against your profile.';
  }
  return included
      ? 'From your profile — you are GST-registered.'
      : 'From your profile — you are not GST-registered.';
}
