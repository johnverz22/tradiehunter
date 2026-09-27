// Data models for the Fixo marketplace (mobile client).
// Money uses String/decimal-safe parsing; timestamps are UTC ISO-8601,
// localized at the client per AGENTS.md. Backend wiring is TODO —
// constructors + fromJson/toJson are real, repositories return stub data.

/// Job posted by a homeowner. Mirrors mockups 05/06/10.
class Job {
  final String id;
  final String title;
  final String category;
  final String suburb;
  final String status; // Requested | Matched | Confirmed | Complete
  final int stage; // 0..3 for JobStepper
  final String? urgency; // Normal | Urgent
  final String? description;
  final List<String> photoUrls;
  final DateTime? createdAtUtc;

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
  });

  factory Job.fromJson(Map<String, dynamic> json) => Job(
        // Backend returns id as int; toString() handles both int and String.
        id: json['id']?.toString() ?? '',
        title: json['title'] as String,
        category: json['category'] as String? ?? '',
        suburb: json['suburb'] as String? ?? '',
        status: json['status'] as String? ?? 'Requested',
        stage: (json['stage'] as num?)?.toInt() ?? 0,
        urgency: json['urgency'] as String?,
        description: json['description'] as String?,
        photoUrls: (json['photoUrls'] as List?)?.cast<String>() ?? const [],
        createdAtUtc: (json['createdAtUtc'] ?? json['createdAt']) != null
            ? DateTime.parse((json['createdAtUtc'] ?? json['createdAt']) as String).toUtc()
            : null,
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
        if (createdAtUtc != null)
          'createdAt': createdAtUtc!.toIso8601String(),
      };
}

/// Matched tradie result. Mirrors mockup 08-match-result.
class TradieMatch {
  final String tradieId;
  final String initials;
  final String name;
  final String trade;
  final bool verified;
  final String distance;
  final double rating;
  final int reviewCount;
  final String? bio;

  const TradieMatch({
    required this.tradieId,
    required this.initials,
    required this.name,
    required this.trade,
    this.verified = true,
    required this.distance,
    required this.rating,
    required this.reviewCount,
    this.bio,
  });

  factory TradieMatch.fromJson(Map<String, dynamic> json) => TradieMatch(
        tradieId: json['tradieId'] as String,
        initials: json['initials'] as String? ?? '',
        name: json['name'] as String? ?? '',
        trade: json['trade'] as String? ?? '',
        verified: json['verified'] as bool? ?? true,
        distance: json['distance'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        bio: json['bio'] as String?,
      );
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
      sentAtUtc: DateTime.parse(
          (json['sentAtUtc'] ?? json['sentAt']) as String).toUtc(),
      readAtUtc: json['readAtUtc'] != null
          ? DateTime.parse(json['readAtUtc'] as String).toUtc()
          : null,
    );
  }
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
  final double averageRating;
  final int reviewCount;

  // Tradie-only
  final String? tradeType;
  final String? businessName;
  final bool? isVerified;

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
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        role: json['role'] as String? ?? 'Homeowner',
        averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        tradeType: json['tradeType'] as String?,
        businessName: json['businessName'] as String?,
        isVerified: json['isVerified'] as bool?,
      );
}
