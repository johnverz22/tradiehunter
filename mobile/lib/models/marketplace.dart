import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

// Data models for the Fixo marketplace (mobile client).
// Money uses String/decimal-safe parsing; timestamps are UTC ISO-8601,
// localized at the client per AGENTS.md. Backend wiring is TODO —
// constructors + fromJson/toJson are real, repositories return stub data.

/// Job posted by a homeowner. Mirrors mockups 05/06/10.
/// Wire shape mirrors backend JobDto: photos[] -> photoUrls,
/// suburb derived from address server-side, stage 0..5 mapped from
/// JobStatus (Requested=0, Payment=1, Booked=2, InProgress=3,
/// Confirmation=4, Completed=5). Urgency is Low|Medium|High|Emergency.
class Job {
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
  final Decimal? totalAmount;
  final String? referenceCode;
  final String? disputeStatus;

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
  });

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
    );
  }

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

  const JobOffer({
    required this.id,
    required this.jobId,
    required this.tradieId,
    required this.offeredAtUtc,
    required this.expiresAtUtc,
    required this.response,
    required this.stage,
  });

  bool get isPending => response == 'Pending';

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

  // Tradie-only
  final String? tradeType;
  final String? businessName;
  final bool? isVerified;
  final bool? hasInsurance;
  final bool? isAvailable;

  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.averageRating,
    required this.reviewCount,
    this.tradeType,
    this.businessName,
    this.isVerified,
    this.hasInsurance,
    this.isAvailable,
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
      tradeType: json['tradeType'] as String?,
      businessName: json['businessName'] as String?,
      isVerified: json['isVerified'] as bool?,
      hasInsurance: json['hasInsurance'] as bool?,
      isAvailable: json['isAvailable'] as bool?,
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
