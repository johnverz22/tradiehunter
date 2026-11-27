import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

// Data models for the Fixo marketplace (mobile client).
// Money uses String/decimal-safe parsing; timestamps are UTC ISO-8601,
// localized at the client per AGENTS.md. Backend wiring is TODO —
// constructors + fromJson/toJson are real, repositories return stub data.

/// Job posted by a homeowner. Mirrors mockups 05/06/10.
/// Wire shape mirrors backend JobDto: photos[] -> photoUrls,
/// suburb derived from address server-side. Urgency is
/// Low|Medium|High|Emergency.
///
/// v1.7 flow (contract #6): [stage] maps to the v2 stepper —
/// Requested=0, Booked=1, InProgress=2, AwaitingConfirmation=3,
/// AwaitingPayment/PaymentReview=4, Completed=5 — for jobs whose
/// [flowVersion] is 2. FlowVersion 1 jobs keep the legacy 4-step mapping
/// (see [stageForStatus]). [totalAmount] is a deprecated wire alias kept
/// parseable for old payloads; new code reads [estimatedTotal] /
/// [finalAmount] instead.
class Job {
  /// Legacy 4-step flow (v1): Requested → Booked → In progress → Done.
  static const int flowVersionLegacy = 1;

  /// v1.7 6-step flow: Requested → Booked → In progress → Review & approve
  /// → Pay → Completed.
  static const int flowVersionV2 = 2;

  /// Job pricing model: `Hourly` (pay when done) or `Project` (quotes).
  static const String jobTypeHourly = 'Hourly';
  static const String jobTypeProject = 'Project';
  final String id;
  final String title;
  final String category;
  final String suburb;
  final String status; // Draft|Requested|Matching|Matched|Confirmed|InProgress|Complete|Cancelled
  final int stage; // 0..5 for JobStepper (Requested=0, Payment=1, Booked=2, InProgress=3, Confirmation=4, Completed=5)
  final String? urgency; // Low | Medium | High | Emergency
  final String? description;
  final List<String> photoUrls;
  final DateTime? createdAtUtc;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? matchedTradieId;
  final String? matchedTradieName;
  final String? homeownerId;
  final int serviceId;
  final DateTime? scheduledStartUtc;
  final int hours;
  final Decimal? hourlyRate;

  /// Deprecated wire alias — present for back-compat with v1 payloads.
  /// New code shows [estimatedTotal] (pre-completion) or [finalAmount]
  /// (post check-out) instead.
  final Decimal? totalAmount;
  final String? referenceCode;
  final String? disputeStatus;

  // ── v1.7 fields (contract #6) ─────────────────────────────────────────────

  /// Flexible | Asap | SpecificDate | DateRange (null on legacy payloads).
  final String? timingPreference;
  final DateTime? scheduledEndUtc;

  /// Homeowner's optional pre-job estimate of hours.
  final double? estimatedHours;

  /// Server-computed estimate before completion (null until priced).
  final Decimal? estimatedTotal;

  /// Hours the tradie reported at check-out.
  final double? finalHours;

  /// Check-out breakdown: labour + approved adjustments = final.
  final Decimal? labourAmount;
  final Decimal? adjustmentsTotal;
  final Decimal? finalAmount;
  final DateTime? completionSubmittedAtUtc;

  /// Hourly | Project.
  final String jobType;

  /// Pricing model agreed at booking (e.g. Hourly | Quote) — informational.
  final String? agreedPricingModel;

  /// 1 = legacy pay-first flow, 2 = v1.7 pay-at-completion flow.
  final int flowVersion;

  /// True when the check-out total exceeds the homeowner's estimate tolerance.
  final bool isAboveEstimateTolerance;

  // ── Project-only optional fields (contract #1) ────────────────────────────
  final Decimal? budgetMin;
  final Decimal? budgetMax;

  /// Tradie | Homeowner | Undecided — who buys materials on a project.
  final String? materialsBy;
  final bool? siteVisitWelcome;
  final String? scopeNotes;

  /// Quote progress for a homeowner's Project job still collecting quotes
  /// ("N of M quotes in"). Null when the server does not send it (older server,
  /// hourly/legacy jobs, tradie view): callers must then keep their existing copy
  /// and never render "0 of 3".
  final int? quotesRequested;
  final int? quotesReceived;

  /// Plan 10 (Q7.3/Q7.8): project is open to the tradie board (not invite-only),
  /// and when it stops accepting new quotes (UTC).
  final bool openToBoard;
  final DateTime? quotesCloseAtUtc;

  const Job({
    required this.id,
    required this.title,
    required this.category,
    required this.suburb,
    required this.status,
    required this.stage,
    this.urgency,
    this.description,
    this.photoUrls = const [],
    this.createdAtUtc,
    this.address,
    this.latitude,
    this.longitude,
    this.matchedTradieId,
    this.matchedTradieName,
    this.homeownerId,
    this.serviceId = 0,
    this.scheduledStartUtc,
    this.hours = 0,
    this.hourlyRate,
    this.totalAmount,
    this.referenceCode,
    this.disputeStatus,
    this.timingPreference,
    this.scheduledEndUtc,
    this.estimatedHours,
    this.estimatedTotal,
    this.finalHours,
    this.labourAmount,
    this.adjustmentsTotal,
    this.finalAmount,
    this.completionSubmittedAtUtc,
    this.jobType = Job.jobTypeHourly,
    this.agreedPricingModel,
    this.flowVersion = Job.flowVersionV2,
    this.isAboveEstimateTolerance = false,
    this.budgetMin,
    this.budgetMax,
    this.materialsBy,
    this.siteVisitWelcome,
    this.scopeNotes,
    this.quotesRequested,
    this.quotesReceived,
    this.openToBoard = false,
    this.quotesCloseAtUtc,
  });

  bool get isProject => jobType == Job.jobTypeProject;

  /// A Project job still in `Requested` whose homeowner has sent at least one
  /// quote request, or an open-board project job collecting quotes (plan 10 Q7.8).
  bool get hasQuoteActivity =>
      isProject &&
      status == 'Requested' &&
      ((quotesRequested ?? 0) > 0 || openToBoard || quotesCloseAtUtc != null);

  /// Whether this job uses the v1.7 pay-at-completion flow.
  bool get usesV2Flow => flowVersion >= Job.flowVersionV2;

  /// Stage for a status string under this job's flow version.
  /// v2 mapping (contract #6): Requested=0, Booked=1, InProgress=2,
  /// AwaitingConfirmation=3, AwaitingPayment/PaymentReview=4, Completed=5.
  /// Legacy flowVersion-1 jobs keep the v1 mapping.
  static int stageForStatus(String status, {int? flowVersion}) {
    if (flowVersion != null && flowVersion < Job.flowVersionV2) {
      return switch (status) {
        'Requested' || 'Matching' => 0,
        'Matched' || 'AwaitingPayment' || 'PaymentReview' => 1,
        'Booked' || 'InProgress' => 2,
        'AwaitingConfirmation' => 3,
        'Completed' => 4,
        _ => 0,
      };
    }
    return switch (status) {
      'Requested' || 'Matching' => 0,
      'Booked' => 1,
      'InProgress' => 2,
      'AwaitingConfirmation' => 3,
      'AwaitingPayment' || 'PaymentReview' => 4,
      'Completed' => 5,
      _ => 0,
    };
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    // Backend sends photos: [{id, url, originalFileName}]; older stubs
    // sent photoUrls directly — accept both.
    final photos = json['photos'] as List?;
    final photoUrls = photos != null
        ? photos
              .whereType<Map>()
              .map((p) => (p['url'] ?? p['Url'])?.toString() ?? '')
              .where((u) => u.isNotEmpty)
              .toList()
        : (json['photoUrls'] as List?)?.cast<String>() ?? const <String>[];
    // Suburb is first comma-segment of address server-side; fall back to
    // address when suburb is missing/empty.
    final rawSuburb = json['suburb'] as String?;
    final address = json['address'] as String?;
    return Job(
      // Backend returns id as int; toString() handles both int and String.
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      suburb: (rawSuburb != null && rawSuburb.isNotEmpty)
          ? rawSuburb
          : (address?.split(',').first.trim() ?? ''),
      status: json['status'] as String? ?? 'Requested',
      stage: (json['stage'] as num?)?.toInt() ?? 0,
      urgency: json['urgency'] as String?,
      description: json['description'] as String?,
      photoUrls: photoUrls,
      createdAtUtc: (json['createdAtUtc'] ?? json['createdAt']) != null
          ? DateTime.parse(
              (json['createdAtUtc'] ?? json['createdAt']) as String,
            ).toUtc()
          : null,
      address: address,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      matchedTradieId: json['matchedTradieId']?.toString(),
      matchedTradieName: json['matchedTradieName']?.toString(),
      homeownerId: json['homeownerId']?.toString(),
      serviceId: (json['serviceId'] as num?)?.toInt() ?? 0,
      scheduledStartUtc: json['scheduledStartUtc'] != null
          ? DateTime.parse(json['scheduledStartUtc'] as String).toUtc()
          : null,
      hours: (json['hours'] as num?)?.toInt() ?? 0,
      hourlyRate: _decimalFromJson(json['hourlyRate']),
      totalAmount: _decimalFromJson(json['totalAmount']),
      referenceCode: json['referenceCode'] as String?,
      disputeStatus: json['disputeStatus'] as String?,
      timingPreference: json['timingPreference'] as String?,
      scheduledEndUtc: json['scheduledEndUtc'] != null
          ? DateTime.parse(json['scheduledEndUtc'] as String).toUtc()
          : null,
      estimatedHours: (json['estimatedHours'] as num?)?.toDouble(),
      estimatedTotal: _decimalFromJson(json['estimatedTotal']),
      finalHours: (json['finalHours'] as num?)?.toDouble(),
      labourAmount: _decimalFromJson(json['labourAmount']),
      adjustmentsTotal: _decimalFromJson(json['adjustmentsTotal']),
      finalAmount: _decimalFromJson(json['finalAmount']),
      completionSubmittedAtUtc: json['completionSubmittedAtUtc'] != null
          ? DateTime.parse(json['completionSubmittedAtUtc'] as String).toUtc()
          : null,
      jobType: json['jobType'] as String? ?? Job.jobTypeHourly,
      agreedPricingModel: json['agreedPricingModel'] as String?,
      flowVersion: (json['flowVersion'] as num?)?.toInt() ?? Job.flowVersionV2,
      isAboveEstimateTolerance:
          json['isAboveEstimateTolerance'] as bool? ?? false,
      budgetMin: _decimalFromJson(json['budgetMin']),
      budgetMax: _decimalFromJson(json['budgetMax']),
      materialsBy: json['materialsBy'] as String?,
      siteVisitWelcome: json['siteVisitWelcome'] as bool?,
      scopeNotes: json['scopeNotes'] as String?,
      quotesRequested: (json['quotesRequested'] as num?)?.toInt(),
      quotesReceived: (json['quotesReceived'] as num?)?.toInt(),
      openToBoard: json['openToBoard'] as bool? ?? false,
      quotesCloseAtUtc: json['quotesCloseAtUtc'] != null
          ? DateTime.parse(json['quotesCloseAtUtc'] as String).toUtc()
          : null,
    );
  }

  /// Structural copy used by live status updates (SignalR) — every field
  /// carries over unless overridden.
  Job copyWith({
    String? status,
    int? stage,
    String? matchedTradieId,
    String? matchedTradieName,
    Decimal? hourlyRate,
    DateTime? scheduledStartUtc,
    String? disputeStatus,
    Decimal? estimatedTotal,
    Decimal? finalAmount,
    double? finalHours,
  }) => Job(
    id: id,
    title: title,
    category: category,
    suburb: suburb,
    status: status ?? this.status,
    stage: stage ?? this.stage,
    urgency: urgency,
    description: description,
    photoUrls: photoUrls,
    createdAtUtc: createdAtUtc,
    address: address,
    latitude: latitude,
    longitude: longitude,
    matchedTradieId: matchedTradieId ?? this.matchedTradieId,
    matchedTradieName: matchedTradieName ?? this.matchedTradieName,
    homeownerId: homeownerId,
    serviceId: serviceId,
    scheduledStartUtc: scheduledStartUtc ?? this.scheduledStartUtc,
    hours: hours,
    hourlyRate: hourlyRate ?? this.hourlyRate,
    totalAmount: totalAmount,
    referenceCode: referenceCode,
    disputeStatus: disputeStatus ?? this.disputeStatus,
    timingPreference: timingPreference,
    scheduledEndUtc: scheduledEndUtc,
    estimatedHours: estimatedHours,
    estimatedTotal: estimatedTotal ?? this.estimatedTotal,
    finalHours: finalHours ?? this.finalHours,
    labourAmount: labourAmount,
    adjustmentsTotal: adjustmentsTotal,
    finalAmount: finalAmount ?? this.finalAmount,
    completionSubmittedAtUtc: completionSubmittedAtUtc,
    jobType: jobType,
    agreedPricingModel: agreedPricingModel,
    flowVersion: flowVersion,
    isAboveEstimateTolerance: isAboveEstimateTolerance,
    budgetMin: budgetMin,
    budgetMax: budgetMax,
    materialsBy: materialsBy,
    siteVisitWelcome: siteVisitWelcome,
    scopeNotes: scopeNotes,
    quotesRequested: quotesRequested,
    quotesReceived: quotesReceived,
    openToBoard: openToBoard,
    quotesCloseAtUtc: quotesCloseAtUtc,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'suburb': suburb,
    'status': status,
    'stage': stage,
    if (urgency != null) 'urgency': urgency,
    if (description != null) 'description': description,
    'photoUrls': photoUrls,
    if (createdAtUtc != null) 'createdAt': createdAtUtc!.toIso8601String(),
    if (address != null) 'address': address,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (matchedTradieId != null) 'matchedTradieId': matchedTradieId,
    if (matchedTradieName != null) 'matchedTradieName': matchedTradieName,
    if (homeownerId != null) 'homeownerId': homeownerId,
    if (serviceId > 0) 'serviceId': serviceId,
    if (scheduledStartUtc != null)
      'scheduledStartUtc': scheduledStartUtc!.toIso8601String(),
    if (hours > 0) 'hours': hours,
    if (hourlyRate != null) 'hourlyRate': hourlyRate.toString(),
    if (totalAmount != null) 'totalAmount': totalAmount.toString(),
    if (referenceCode != null) 'referenceCode': referenceCode,
  };
}

Decimal? _decimalFromJson(dynamic value) =>
    value == null ? null : Decimal.tryParse(value.toString());

/// Net amount the tradie receives after the platform commission, mirroring
/// `PayoutService` exactly: `commission = Round(total * percent / 100, 2)`
/// with .NET's default half-to-even rounding, then `net = total - commission`.
/// Returns null for missing or non-positive inputs — callers must omit the
/// net line rather than show a fabricated figure.
Decimal? payoutNetAmount(Decimal? total, Decimal? commissionPercent) {
  if (total == null || commissionPercent == null) return null;
  if (total <= Decimal.zero || commissionPercent < Decimal.zero) return null;
  // commission * 100 == total * percent, rounded half-to-even to the cent.
  final commissionCents = _roundHalfEven(
    total.toRational() * commissionPercent.toRational(),
  );
  final commission = Rational(commissionCents, BigInt.from(100)).toDecimal();
  return total - commission;
}

/// Round a non-negative [Rational] to the nearest integer, ties to even
/// (.NET `Math.Round` default). Money here is always non-negative.
BigInt _roundHalfEven(Rational value) {
  final q = value.numerator ~/ value.denominator;
  final remainderTwice = (value.numerator % value.denominator) * BigInt.two;
  if (remainderTwice > value.denominator ||
      (remainderTwice == value.denominator && q.isOdd)) {
    return q + BigInt.one;
  }
  return q;
}

/// Counterparty contact for a booked-or-later job (V15-15).
/// Served by GET /api/jobs/:id/contact — participant-only, contactable
/// statuses only. [phoneNumber] is null when the user never set one; callers
/// must hide the Call action rather than invent a number.
class JobContact {
  final String userId;
  final String firstName;
  final String? phoneNumber;

  const JobContact({
    required this.userId,
    required this.firstName,
    this.phoneNumber,
  });

  factory JobContact.fromJson(Map<String, dynamic> json) => JobContact(
    userId: json['userId']?.toString() ?? '',
    firstName: json['firstName'] as String? ?? '',
    phoneNumber: json['phoneNumber'] as String?,
  );
}

/// A service catalog entry used to start a job request.
class ServiceOption {
  final int id;
  final String name;
  final String category;

  const ServiceOption({
    required this.id,
    required this.name,
    required this.category,
  });

  factory ServiceOption.fromJson(Map<String, dynamic> json) => ServiceOption(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    category: json['category'] as String? ?? '',
  );
}

/// A nearby verified tradie rate returned by GET /api/services/search.
class ServiceRateOption {
  final String tradieId;
  final String name;
  final String? businessName;
  final Decimal hourlyRate;
  final double distanceKm;

  const ServiceRateOption({
    required this.tradieId,
    required this.name,
    this.businessName,
    required this.hourlyRate,
    required this.distanceKm,
  });

  factory ServiceRateOption.fromJson(Map<String, dynamic> json) =>
      ServiceRateOption(
        tradieId: json['tradieId']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        businessName: json['businessName'] as String?,
        hourlyRate: _decimalFromJson(json['hourlyRate']) ?? Decimal.zero,
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      );
}

/// A single sequential offer sent to a tradie (P3-01 / P3-07).
/// Mirrors backend OfferDto. Only one offer is Pending per job at a time;
/// after a response or timeout the next ranked tradie receives theirs.
///
/// v1.7 (contract #3/#4): a direct request carries [kind]
/// (`Direct` | `QuoteRequest` | `Auto`), the rate snapshotted at request
/// time ([hourlyRateSnapshot]), the tradie's display [tradieName], the
/// homeowner's optional pre-acceptance [message] and the [jobTitle].
class JobOffer {
  final String id;
  final String jobId;
  final String tradieId;

  /// When the offer was dispatched (UTC).
  final DateTime offeredAtUtc;

  /// Deadline for the tradie to respond (UTC). The tradie screen counts down
  /// against this, localized at the UI layer.
  final DateTime expiresAtUtc;

  /// Pending | Accepted | Declined | TimedOut
  final String response;

  /// Auto (strict radius) | Broadened (expanded radius).
  final String stage;

  /// Direct | QuoteRequest | Auto — how this offer was created (v1.7).
  final String kind;

  /// Hourly rate copied onto the job when this offer is accepted.
  final Decimal? hourlyRateSnapshot;

  /// Optional homeowner message attached to a direct request.
  final String? message;

  /// Display name of the tradie being asked (homeowner-facing).
  final String? tradieName;

  /// Title of the job the offer belongs to.
  final String? jobTitle;

  const JobOffer({
    required this.id,
    required this.jobId,
    required this.tradieId,
    required this.offeredAtUtc,
    required this.expiresAtUtc,
    required this.response,
    required this.stage,
    this.kind = 'Auto',
    this.hourlyRateSnapshot,
    this.message,
    this.tradieName,
    this.jobTitle,
  });

  bool get isPending => response == 'Pending';

  bool get isQuoteRequest => kind == 'QuoteRequest';

  /// Time left to respond. Zero or negative once the offer has expired.
  Duration remaining([DateTime? now]) =>
      expiresAtUtc.difference((now ?? DateTime.now()).toUtc());

  factory JobOffer.fromJson(Map<String, dynamic> json) => JobOffer(
    id: json['id']?.toString() ?? '',
    jobId: json['jobId']?.toString() ?? '',
    tradieId: json['tradieId']?.toString() ?? '',
    offeredAtUtc: DateTime.parse(json['offeredAtUtc'] as String).toUtc(),
    expiresAtUtc: DateTime.parse(json['expiresAtUtc'] as String).toUtc(),
    response: json['response'] as String? ?? 'Pending',
    stage: json['stage'] as String? ?? 'Auto',
    kind: json['kind'] as String? ?? 'Auto',
    hourlyRateSnapshot: _decimalFromJson(json['hourlyRateSnapshot']),
    message: json['message'] as String?,
    tradieName: json['tradieName'] as String?,
    jobTitle: json['jobTitle'] as String?,
  );
}

/// Matched tradie result. Mirrors mockup 08-match-result.
/// Wire shape mirrors backend TradieMatchDto: distance is a display string
/// ("1.2 km away"), distanceKm is the numeric value.
class TradieMatch {
  final String tradieId;
  final String initials;
  final String name;
  final String trade;
  final bool verified;
  final bool hasInsurance;
  final String distance;
  final double distanceKm;

  /// A distance is only worth showing when the server actually computed one;
  /// "0.0 km away" means unknown, not "next door".
  bool get hasDistance => distance.trim().isNotEmpty && distanceKm > 0;

  final double? rating;
  final int? reviewCount;
  final String? bio;

  const TradieMatch({
    required this.tradieId,
    required this.initials,
    required this.name,
    required this.trade,
    this.verified = false,
    this.hasInsurance = false,
    required this.distance,
    this.distanceKm = 0,
    required this.rating,
    required this.reviewCount,
    this.bio,
  });

  factory TradieMatch.fromJson(Map<String, dynamic> json) {
    final numKm = (json['distanceKm'] as num?)?.toDouble() ?? 0;
    final rawDistance = json['distance'] as String?;
    return TradieMatch(
      tradieId: json['tradieId']?.toString() ?? '',
      initials: json['initials'] as String? ?? '',
      name: json['name'] as String? ?? '',
      trade: json['trade'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
      hasInsurance: json['hasInsurance'] as bool? ?? false,
      distance: (rawDistance != null && rawDistance.isNotEmpty)
          ? rawDistance
          : (numKm > 0 ? '${numKm.toStringAsFixed(1)} km away' : ''),
      distanceKm: numKm,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt(),
      bio: json['bio'] as String?,
    );
  }
}

/// Chat message. Transport is the SignalR hub per AGENTS.md
/// (REST history + hub live messages). Mirrors mockup 11-chat.
class ChatMessage {
  final String id;
  final String jobId;
  final String senderId;
  final String senderName;
  final bool sentByMe;
  final String? text;
  final String? imageUrl;
  final DateTime sentAtUtc;
  final DateTime? readAtUtc;

  const ChatMessage({
    required this.id,
    required this.jobId,
    required this.senderId,
    this.senderName = '',
    required this.sentByMe,
    this.text,
    this.imageUrl,
    required this.sentAtUtc,
    this.readAtUtc,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return ChatMessage(
      id: rawId?.toString() ?? '',
      jobId: json['jobId']?.toString() ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      // Server sets sentByMe based on the requesting user. When arriving via
      // hub broadcast the client compares senderId against its own userId.
      sentByMe: json['sentByMe'] as bool? ?? false,
      text: (json['content'] ?? json['text']) as String?,
      imageUrl: json['imageUrl'] as String?,
      sentAtUtc: DateTime.parse((json['sentAtUtc'] ?? json['sentAt']) as String)
          .toUtc(),
      readAtUtc: json['readAtUtc'] != null
          ? DateTime.parse(json['readAtUtc'] as String).toUtc()
          : null,
    );
  }
}

/// Inbox row from GET /api/chat/conversations (V15-16).
///
/// Participant-first: [otherFirstName] leads the row and [jobTitle] is the
/// subtitle. [lastMessage]/[unreadCount] are always real — the preview is null
/// for a thread with no messages, never a status label or placeholder.
class ConversationSummary {
  final String jobId;
  final String jobTitle;
  final String status;
  final String otherUserId;
  final String otherFirstName;
  final String? lastMessage;
  final bool lastMessageMine;
  final DateTime? lastMessageAtUtc;
  final int unreadCount;

  const ConversationSummary({
    required this.jobId,
    required this.jobTitle,
    required this.status,
    required this.otherUserId,
    this.otherFirstName = '',
    this.lastMessage,
    this.lastMessageMine = false,
    this.lastMessageAtUtc,
    this.unreadCount = 0,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        jobId: json['jobId']?.toString() ?? '',
        jobTitle: json['jobTitle'] as String? ?? '',
        status: json['status'] as String? ?? '',
        otherUserId: json['otherUserId'] as String? ?? '',
        otherFirstName: json['otherFirstName'] as String? ?? '',
        lastMessage: json['lastMessageContent'] as String?,
        lastMessageMine: json['lastMessageSentByMe'] as bool? ?? false,
        lastMessageAtUtc: json['lastMessageSentAtUtc'] != null
            ? DateTime.parse(json['lastMessageSentAtUtc'] as String).toUtc()
            : null,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );
}

/// Review left after a completed job. Mirrors mockups 12/13.
class Review {
  final String id;
  final int jobId;
  final String reviewerId;
  final String reviewerName;
  final String revieweeId;
  final int rating; // 1..5
  final String? comment;
  final DateTime createdAtUtc;

  const Review({
    required this.id,
    required this.jobId,
    required this.reviewerId,
    required this.reviewerName,
    required this.revieweeId,
    required this.rating,
    this.comment,
    required this.createdAtUtc,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'] as String? ?? '',
    jobId: (json['jobId'] as num?)?.toInt() ?? 0,
    reviewerId: json['reviewerId'] as String? ?? '',
    reviewerName: json['reviewerName'] as String? ?? '',
    revieweeId: json['revieweeId'] as String? ?? '',
    rating: (json['rating'] as num?)?.toInt() ?? 5,
    comment: json['comment'] as String?,
    createdAtUtc: json['createdAtUtc'] != null
        ? DateTime.parse(json['createdAtUtc'] as String).toUtc()
        : DateTime.now().toUtc(),
  );

  /// Human-readable relative date label for display.
  String get relativeDate {
    final diff = DateTime.now().toUtc().difference(createdAtUtc);
    if (diff.inDays < 1) return 'today';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).round()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).round()} months ago';
    return '${(diff.inDays / 365).round()} years ago';
  }
}

/// Public profile data returned by GET /api/profile/{id} (M4-03, M4-10).
class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String role; // Homeowner | Tradie
  final double? averageRating;
  final int? reviewCount;

  /// Account creation date — drives the H17 "Member since March 2026" line.
  final DateTime? memberSinceUtc;

  // Tradie-only
  final String? tradeType;
  final String? businessName;
  final bool? isVerified;
  final bool? hasInsurance;
  final bool? isAvailable;

  /// Self-written About blurb (H17 "About" section). Nullable/empty → section
  /// is omitted rather than showing a stub.
  final String? bio;

  /// Trade registration number, shown as "NZ Reg #E2491" (H17). Owner-set.
  final String? registrationNumber;

  /// D8: whether this tradie is GST registered. Drives the
  /// "Incl. GST" / "No GST charged" label wherever a rate is shown to a
  /// homeowner. Null on legacy payloads → label omitted (never guessed).
  final bool? isGstRegistered;

  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.averageRating,
    required this.reviewCount,
    this.memberSinceUtc,
    this.tradeType,
    this.businessName,
    this.isVerified,
    this.hasInsurance,
    this.isAvailable,
    this.bio,
    this.registrationNumber,
    this.isGstRegistered,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Backend serializes UserRole enum as int (Homeowner=0, Tradie=1,
    // Staff=2, Superadmin=3); accept int or string for forward-compat.
    final rawRole = json['role'];
    final role = rawRole is int
        ? (rawRole == 1
              ? 'Tradie'
              : rawRole == 2
              ? 'Staff'
              : rawRole == 3
              ? 'Superadmin'
              : 'Homeowner')
        : (rawRole as String? ?? 'Homeowner');
    return UserProfile(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      role: role,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt(),
      memberSinceUtc: DateTime.tryParse(
        json['memberSinceUtc']?.toString() ?? '',
      ),
      tradeType: json['tradeType'] as String?,
      businessName: json['businessName'] as String?,
      isVerified: json['isVerified'] as bool?,
      hasInsurance: json['hasInsurance'] as bool?,
      isAvailable: json['isAvailable'] as bool?,
      bio: (json['bio'] as String?)?.trim(),
      registrationNumber: (json['registrationNumber'] as String?)
          ?.trim()
          .toUpperCase(),
      isGstRegistered: json['isGstRegistered'] as bool?,
    );
  }
}

/// Tradie weekly earnings summary from `GET /api/tradie/earnings` (v1.5 D4).
///
/// Every amount is the server's own decimal net figure — the client never
/// sums loaded jobs. `earnedNet`/`processedNet` cover the stated period;
/// `pendingNet` is the current all-time outstanding balance and must not be
/// added to the weekly figures.
class TradieEarnings {
  final DateTime periodStartUtc;
  final DateTime periodEndUtc;
  final DateTime asOfUtc;
  final String timeZone;
  final Decimal? earnedNet;
  final Decimal? processedNet;
  final Decimal? pendingNet;
  final Decimal? failedNet;

  const TradieEarnings({
    required this.periodStartUtc,
    required this.periodEndUtc,
    required this.asOfUtc,
    required this.timeZone,
    this.earnedNet,
    this.processedNet,
    this.pendingNet,
    this.failedNet,
  });

  /// A missing or unparseable amount stays null so the UI can show an
  /// unavailable state instead of a fabricated zero.
  static Decimal? _amount(dynamic value) =>
      value == null ? null : Decimal.tryParse(value.toString());

  factory TradieEarnings.fromJson(Map<String, dynamic> json) => TradieEarnings(
    periodStartUtc: DateTime.parse(json['periodStartUtc'] as String).toUtc(),
    periodEndUtc: DateTime.parse(json['periodEndUtc'] as String).toUtc(),
    asOfUtc: DateTime.parse(json['asOfUtc'] as String).toUtc(),
    timeZone: json['timeZone'] as String? ?? 'Pacific/Auckland',
    earnedNet: _amount(json['earnedNet']),
    processedNet: _amount(json['processedNet']),
    pendingNet: _amount(json['pendingNet']),
    failedNet: _amount(json['failedNet']),
  );
}

/// One tradie row on the Choose-a-Tradie screen (v1.7 P12-05/P12-06).
/// Mirrors backend TradieListEntryDto from GET /api/jobs/{id}/tradies.
/// [hourlyRate] is the job's-service final consumer price — GST-inclusive
/// when [isGstRegistered] is true (D8); the label comes from
/// [gstLabelFor]. [score] is the server's own "best" ranking value.
class TradieListEntry {
  final String tradieId;
  final String name;
  final String? businessName;
  final String initials;
  final bool verified;
  final bool insured;
  final bool available;
  final double? rating;
  final int? reviewCount;
  final int? completedJobs;
  final double distanceKm;

  /// Server-rendered distance display string ("1.2 km away"); empty when
  /// no distance was computed.
  final String distance;
  final Decimal? hourlyRate;
  final bool? isGstRegistered;
  final double? score;
  final String? bio;

  const TradieListEntry({
    required this.tradieId,
    required this.name,
    this.businessName,
    required this.initials,
    this.verified = false,
    this.insured = false,
    this.available = false,
    this.rating,
    this.reviewCount,
    this.completedJobs,
    required this.distanceKm,
    this.distance = '',
    this.hourlyRate,
    this.isGstRegistered,
    this.score,
    this.bio,
  });

  /// Name shown on the card — business name when present, else the person.
  String get displayName {
    final business = businessName?.trim();
    if (business != null && business.isNotEmpty) return business;
    return name;
  }

  /// A distance is only worth showing when the server computed one.
  bool get hasDistance => distance.trim().isNotEmpty || distanceKm > 0;

  factory TradieListEntry.fromJson(Map<String, dynamic> json) {
    final numKm = (json['distanceKm'] as num?)?.toDouble() ?? 0;
    final rawDistance = json['distance'] as String?;
    return TradieListEntry(
      tradieId: json['tradieId']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      businessName: json['businessName'] as String?,
      initials: json['initials'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
      insured: json['insured'] as bool? ?? false,
      available: json['available'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt(),
      completedJobs: (json['completedJobs'] as num?)?.toInt(),
      distanceKm: numKm,
      distance: (rawDistance != null && rawDistance.isNotEmpty)
          ? rawDistance
          : (numKm > 0 ? '${numKm.toStringAsFixed(1)} km away' : ''),
      hourlyRate: _decimalFromJson(json['hourlyRate']),
      isGstRegistered: json['isGstRegistered'] as bool?,
      score: (json['score'] as num?)?.toDouble(),
      bio: json['bio'] as String?,
    );
  }
}

/// D8: GST label shown next to any rate/price a homeowner sees.
/// Returns null when the GST status is unknown — the label is omitted
/// rather than guessed.
String? gstLabelFor(bool? isGstRegistered) {
  if (isGstRegistered == null) return null;
  return isGstRegistered ? 'Incl. GST' : 'No GST charged';
}

/// A tradie-proposed extra cost during a job (v1.7 P12-17).
/// Mirrors backend JobAdjustmentDto from GET /api/jobs/{id}/adjustments.
class JobAdjustment {
  static const kindMaterials = 'Materials';
  static const kindExtraLabour = 'ExtraLabour';
  static const kindTravel = 'Travel';
  static const kindOther = 'Other';

  static const statusPending = 'Pending';
  static const statusApproved = 'Approved';
  static const statusDeclined = 'Declined';
  static const statusWithdrawn = 'Withdrawn';
  static const statusExpired = 'Expired';

  final String id;
  final String jobId;
  final String proposedByTradieId;
  final String proposedByTradieName;

  /// Materials | ExtraLabour | Travel | Other.
  final String kind;
  final String description;
  final Decimal amount;

  /// Blob key of an attached receipt/photo — null when the tradie sent none.
  final String? evidenceUrl;

  /// Pending | Approved | Declined | Withdrawn | Expired.
  final String status;
  final DateTime createdAtUtc;
  final DateTime? respondedAtUtc;
  final String? responseNote;
  final DateTime? expiresAtUtc;

  const JobAdjustment({
    required this.id,
    required this.jobId,
    required this.proposedByTradieId,
    required this.proposedByTradieName,
    required this.kind,
    required this.description,
    required this.amount,
    this.evidenceUrl,
    required this.status,
    required this.createdAtUtc,
    this.respondedAtUtc,
    this.responseNote,
    this.expiresAtUtc,
  });

  bool get isPending => status == JobAdjustment.statusPending;
  bool get isApproved => status == JobAdjustment.statusApproved;

  factory JobAdjustment.fromJson(Map<String, dynamic> json) => JobAdjustment(
    id: json['id']?.toString() ?? '',
    jobId: json['jobId']?.toString() ?? '',
    proposedByTradieId: json['proposedByTradieId']?.toString() ?? '',
    proposedByTradieName: json['proposedByTradieName'] as String? ?? '',
    kind: json['kind'] as String? ?? JobAdjustment.kindOther,
    description: json['description'] as String? ?? '',
    amount: _decimalFromJson(json['amount']) ?? Decimal.zero,
    evidenceUrl: json['evidenceUrl'] as String?,
    status: json['status'] as String? ?? JobAdjustment.statusPending,
    createdAtUtc: json['createdAtUtc'] != null
        ? DateTime.parse(json['createdAtUtc'] as String).toUtc()
        : DateTime.now().toUtc(),
    respondedAtUtc: json['respondedAtUtc'] != null
        ? DateTime.parse(json['respondedAtUtc'] as String).toUtc()
        : null,
    responseNote: json['responseNote'] as String?,
    expiresAtUtc: json['expiresAtUtc'] != null
        ? DateTime.parse(json['expiresAtUtc'] as String).toUtc()
        : null,
  );
}

/// Server response from POST /api/jobs/{id}/check-out (v1.7 contract #7).
/// Every amount is server-computed; the UI renders these verbatim.
class CheckOutSummary {
  final String jobId;
  final double? finalHours;
  final Decimal? hourlyRate;
  final Decimal? labourAmount;
  final Decimal? adjustmentsTotal;
  final Decimal? finalAmount;
  final Decimal? estimatedTotal;

  /// True when [finalAmount] exceeds the homeowner's estimate tolerance —
  /// the homeowner must review before approving.
  final bool exceedsTolerance;

  /// Server-supplied explanation of the tolerance result.
  final String? toleranceNote;
  final DateTime? completionSubmittedAtUtc;

  const CheckOutSummary({
    required this.jobId,
    this.finalHours,
    this.hourlyRate,
    this.labourAmount,
    this.adjustmentsTotal,
    this.finalAmount,
    this.estimatedTotal,
    this.exceedsTolerance = false,
    this.toleranceNote,
    this.completionSubmittedAtUtc,
  });

  factory CheckOutSummary.fromJson(Map<String, dynamic> json) =>
      CheckOutSummary(
        jobId: json['jobId']?.toString() ?? '',
        finalHours: (json['finalHours'] as num?)?.toDouble(),
        hourlyRate: _decimalFromJson(json['hourlyRate']),
        labourAmount: _decimalFromJson(json['labourAmount']),
        adjustmentsTotal: _decimalFromJson(json['adjustmentsTotal']),
        finalAmount: _decimalFromJson(json['finalAmount']),
        estimatedTotal: _decimalFromJson(json['estimatedTotal']),
        exceedsTolerance: json['exceedsTolerance'] as bool? ?? false,
        toleranceNote: json['toleranceNote'] as String?,
        completionSubmittedAtUtc: json['completionSubmittedAtUtc'] != null
            ? DateTime.parse(json['completionSubmittedAtUtc'] as String).toUtc()
            : null,
      );
}

/// A tradie's quote for a project job (v1.7 P12-23).
/// Mirrors backend QuoteDto from GET/POST /api/jobs/{id}/quotes.
class Quote {
  static const pricingFixed = 'Fixed';
  static const pricingEstimateRange = 'EstimateRange';
  static const pricingHourlyWithCap = 'HourlyWithCap';

  /// Wire value is `Submitted` (backend `QuoteStatus.Submitted`). Older fixtures
  /// used `Pending`; [isOpen] accepts both.
  static const statusPending = 'Submitted';
  static const statusAccepted = 'Accepted';
  static const statusDeclined = 'Declined';
  static const statusWithdrawn = 'Withdrawn';
  static const statusExpired = 'Expired';

  final String id;
  final String jobId;
  final String tradieId;
  final String tradieName;
  final String? businessName;
  final String initials;
  final bool verified;
  final double? rating;
  final int? reviewCount;

  /// Fixed | EstimateRange | HourlyWithCap.
  final String pricingModel;
  final Decimal? amount;
  final Decimal? minAmount;
  final Decimal? maxAmount;
  final Decimal? cap;
  final String? inclusions;
  final String? exclusions;
  final bool materialsIncluded;

  /// GST rule (contract #12): true for GST-registered tradies, false
  /// otherwise — the backend enforces this on submit.
  final bool gstIncluded;
  final DateTime? proposedStartUtc;
  final int? estimatedDurationDays;
  final DateTime? validUntilUtc;
  final String status;

  const Quote({
    required this.id,
    required this.jobId,
    required this.tradieId,
    required this.tradieName,
    this.businessName,
    required this.initials,
    this.verified = false,
    this.rating,
    this.reviewCount,
    required this.pricingModel,
    this.amount,
    this.minAmount,
    this.maxAmount,
    this.cap,
    this.inclusions,
    this.exclusions,
    this.materialsIncluded = false,
    this.gstIncluded = false,
    this.proposedStartUtc,
    this.estimatedDurationDays,
    this.validUntilUtc,
    this.status = Quote.statusPending,
  });

  /// Still awaiting the homeowner's decision.
  bool get isOpen => status == Quote.statusPending || status == 'Pending';

  bool get isFixed => pricingModel == Quote.pricingFixed;
  bool get isEstimateRange => pricingModel == Quote.pricingEstimateRange;
  bool get isHourlyWithCap => pricingModel == Quote.pricingHourlyWithCap;

  /// Display name — business name when present, else the person.
  String get displayName {
    final business = businessName?.trim();
    if (business != null && business.isNotEmpty) return business;
    return tradieName;
  }

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    id: json['id']?.toString() ?? '',
    jobId: json['jobId']?.toString() ?? '',
    tradieId: json['tradieId']?.toString() ?? '',
    tradieName: json['tradieName'] as String? ?? '',
    businessName: json['businessName'] as String?,
    initials: json['initials'] as String? ?? '',
    verified: json['verified'] as bool? ?? false,
    rating: (json['rating'] as num?)?.toDouble(),
    reviewCount: (json['reviewCount'] as num?)?.toInt(),
    pricingModel: json['pricingModel'] as String? ?? Quote.pricingFixed,
    amount: _decimalFromJson(json['amount']),
    minAmount: _decimalFromJson(json['minAmount']),
    maxAmount: _decimalFromJson(json['maxAmount']),
    cap: _decimalFromJson(json['cap']),
    inclusions: json['inclusions'] as String?,
    exclusions: json['exclusions'] as String?,
    materialsIncluded: json['materialsIncluded'] as bool? ?? false,
    gstIncluded: json['gstIncluded'] as bool? ?? false,
    proposedStartUtc: json['proposedStartUtc'] != null
        ? DateTime.parse(json['proposedStartUtc'] as String).toUtc()
        : null,
    estimatedDurationDays: (json['estimatedDurationDays'] as num?)?.toInt(),
    validUntilUtc: json['validUntilUtc'] != null
        ? DateTime.parse(json['validUntilUtc'] as String).toUtc()
        : null,
    status: json['status'] as String? ?? Quote.statusPending,
  );
}

/// One open project job on the tradie "Available jobs" board (plan 10 Q7.4/Q7.10).
/// Mirrors backend `AvailableJobDto`. Address is masked to suburb until Booked.
class AvailableJob {
  final String id;
  final String title;
  final String category;
  final String description;
  final String urgency;
  final int serviceId;
  final String? suburb;
  final double? distanceKm;
  final String? scopeNotes;
  final Decimal? budgetMin;
  final Decimal? budgetMax;
  final String materialsBy;
  final bool siteVisitWelcome;
  final String timingPreference;
  final DateTime? scheduledStartUtc;
  final DateTime? scheduledEndUtc;
  final int quotesReceived;
  final DateTime quotesCloseAtUtc;
  final DateTime createdAtUtc;
  final List<String> photoUrls;

  /// Optional server-supplied quote validity window (Q4.2 / Q7.10); omitted if absent.
  final int? quoteValidityHours;

  const AvailableJob({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.urgency,
    this.serviceId = 0,
    this.suburb,
    this.distanceKm,
    this.scopeNotes,
    this.budgetMin,
    this.budgetMax,
    this.materialsBy = 'Undecided',
    this.siteVisitWelcome = false,
    this.timingPreference = 'Flexible',
    this.scheduledStartUtc,
    this.scheduledEndUtc,
    this.quotesReceived = 0,
    required this.quotesCloseAtUtc,
    required this.createdAtUtc,
    this.photoUrls = const [],
    this.quoteValidityHours,
  });

  factory AvailableJob.fromJson(Map<String, dynamic> json) {
    final photos = json['photos'] as List?;
    final photoUrls = photos != null
        ? photos
              .whereType<Map>()
              .map((p) => (p['url'] ?? p['Url'])?.toString() ?? '')
              .where((u) => u.isNotEmpty)
              .toList()
        : (json['photoUrls'] as List?)?.cast<String>() ?? const <String>[];
    return AvailableJob(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      urgency: json['urgency'] as String? ?? 'Medium',
      serviceId: (json['serviceId'] as num?)?.toInt() ?? 0,
      suburb: json['suburb'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      scopeNotes: json['scopeNotes'] as String?,
      budgetMin: _decimalFromJson(json['budgetMin']),
      budgetMax: _decimalFromJson(json['budgetMax']),
      materialsBy: json['materialsBy'] as String? ?? 'Undecided',
      siteVisitWelcome: json['siteVisitWelcome'] as bool? ?? false,
      timingPreference: json['timingPreference'] as String? ?? 'Flexible',
      scheduledStartUtc: json['scheduledStartUtc'] != null
          ? DateTime.parse(json['scheduledStartUtc'] as String).toUtc()
          : null,
      scheduledEndUtc: json['scheduledEndUtc'] != null
          ? DateTime.parse(json['scheduledEndUtc'] as String).toUtc()
          : null,
      quotesReceived: (json['quotesReceived'] as num?)?.toInt() ?? 0,
      quotesCloseAtUtc: json['quotesCloseAtUtc'] != null
          ? DateTime.parse(json['quotesCloseAtUtc'] as String).toUtc()
          : DateTime.now().toUtc(),
      createdAtUtc: json['createdAtUtc'] != null
          ? DateTime.parse(json['createdAtUtc'] as String).toUtc()
          : DateTime.now().toUtc(),
      photoUrls: photoUrls,
      quoteValidityHours: (json['quoteValidityHours'] as num?)?.toInt(),
    );
  }
}
