/// Data models for the tradie onboarding wizard (P1-09).
///
/// Wire contract notes, all from the .NET side:
///  * `System.Text.Json` serialises `TimeSpan` as `"HH:mm:ss"` (optionally
///    `[-][d.]hh:mm:ss[.fffffff]`). No custom converter is registered, so
///    the client must parse — and send — that shape.
///  * Enum values cross the wire as PascalCase strings produced by
///    `Enum.ToString()`, e.g. `"Pending"`, `"License"`.
///  * `HourlyRate` is `decimal` and arrives as a JSON *number*. It is held
///    client-side as a `Decimal` (never a `double`) so the tradie can type
///    and revise a rate without accumulating binary floating-point error;
///    the single conversion to `double` happens at the JSON boundary.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart' show TimeOfDay;

/// A trade in the backend `Service` catalog (`GET /api/tradie/services`).
class TradieService {
  final int id;
  final String name;

  /// `TradeCategory` name, e.g. `"Plumber"`.
  final String category;

  const TradieService({
    required this.id,
    required this.name,
    required this.category,
  });

  factory TradieService.fromJson(Map<String, dynamic> json) => TradieService(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'category': category};
}

/// One service the tradie offers plus the hourly rate they charge for it.
class TradieRateEntry {
  final int serviceId;
  final String serviceName;
  final Decimal hourlyRate;

  const TradieRateEntry({
    required this.serviceId,
    required this.serviceName,
    required this.hourlyRate,
  });

  factory TradieRateEntry.fromJson(Map<String, dynamic> json) => TradieRateEntry(
        serviceId: (json['serviceId'] as num?)?.toInt() ?? 0,
        serviceName: json['serviceName'] as String? ?? '',
        hourlyRate: parseDecimal(json['hourlyRate']) ?? Decimal.zero,
      );

  /// Matches `RateInputDto` on `POST /api/tradie/rates`.
  Map<String, dynamic> toInputJson() =>
      {'serviceId': serviceId, 'hourlyRate': hourlyRate.toDouble()};
}

/// A tradie's availability window on one weekday.
class TradieScheduleSlot {
  /// `0` = Sunday … `6` = Saturday, matching .NET's `DayOfWeek`.
  final int weekday;
  final TimeOfDay start;
  final TimeOfDay end;

  const TradieScheduleSlot({
    required this.weekday,
    required this.start,
    required this.end,
  });

  factory TradieScheduleSlot.fromJson(Map<String, dynamic> json) {
    final weekday = (json['weekday'] as num?)?.toInt() ?? 0;
    return TradieScheduleSlot(
      weekday: weekday,
      start: parseApiTimeOfDay(json['startTime']) ?? const TimeOfDay(hour: 9, minute: 0),
      end: parseApiTimeOfDay(json['endTime']) ?? const TimeOfDay(hour: 17, minute: 0),
    );
  }

  /// Matches `TradieScheduleDto`. The backend validates `start < end`, one
  /// slot per weekday, and `end <= 24:00`.
  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'startTime': formatApiTimeOfDay(start),
        'endTime': formatApiTimeOfDay(end),
      };

  TradieScheduleSlot copyWith({TimeOfDay? start, TimeOfDay? end}) =>
      TradieScheduleSlot(
        weekday: weekday,
        start: start ?? this.start,
        end: end ?? this.end,
      );
}

/// A verification document the tradie uploaded (licence, insurance, …).
class TradieCredential {
  final int id;

  /// `CredentialType` name, e.g. `"License"`.
  final String type;
  final String originalFileName;

  /// `CredentialStatus` name: `"Pending"`, `"Approved"`, `"Rejected"`.
  final String status;
  final String? rejectReason;
  final String? downloadUrl;

  const TradieCredential({
    required this.id,
    required this.type,
    required this.originalFileName,
    required this.status,
    this.rejectReason,
    this.downloadUrl,
  });

  factory TradieCredential.fromJson(Map<String, dynamic> json) =>
      TradieCredential(
        id: (json['id'] as num?)?.toInt() ?? 0,
        type: json['type'] as String? ?? '',
        originalFileName: json['originalFileName'] as String? ?? '',
        status: json['status'] as String? ?? 'Pending',
        rejectReason: json['rejectReason'] as String?,
        downloadUrl: json['downloadUrl'] as String?,
      );

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';
}

/// Credential types accepted by `POST /api/tradie/credentials` (form field
/// `type`), mirroring the backend `CredentialType` enum.
enum CredentialKind {
  license('License', 'Trade licence'),
  insurance('Insurance', 'Public liability insurance'),
  certification('Certification', 'Certification or qualification'),
  other('Other', 'Other supporting document');

  /// Value sent as the `type` form field.
  final String wireName;
  final String label;

  const CredentialKind(this.wireName, this.label);

  static CredentialKind fromWire(String? value) {
    final v = value?.toLowerCase();
    return CredentialKind.values.firstWhere(
      (k) => k.wireName.toLowerCase() == v,
      orElse: () => CredentialKind.other,
    );
  }
}

/// File extensions the backend accepts — the `contentType` allow-list in
/// `ProfileService` is JPEG, PNG and PDF only.
const kCredentialExtensions = <String>['jpg', 'jpeg', 'png', 'pdf'];

/// The backend caps credential uploads at 10 MB.
const kMaxCredentialBytes = 10 * 1024 * 1024;

/// Weekday numbers in the Monday-first order the wizard renders them.
/// .NET's `DayOfWeek` is Sunday-first, so the list ends with `0`.
const kWeekdayOrder = <int>[1, 2, 3, 4, 5, 6, 0];

/// Indexed by .NET weekday number (`0` = Sunday).
const kWeekdayLabels = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/// Short label for the schedule rows, e.g. `"Mon"`.
String weekdayShortLabel(int weekday) =>
    kWeekdayLabels[weekday.clamp(0, 6)].substring(0, 3);

/// Parses a `TimeSpan` JSON string into a [TimeOfDay].
/// Returns null for anything unparseable so callers can fall back safely.
TimeOfDay? parseApiTimeOfDay(Object? raw) {
  if (raw is! String) return null;
  var value = raw.trim();
  if (value.isEmpty) return null;

  // Strip an optional .NET day prefix, e.g. `1.09:00:00`.
  final firstColon = value.indexOf(':');
  final firstDot = value.indexOf('.');
  if (firstColon > 0 && firstDot > 0 && firstDot < firstColon) {
    value = value.substring(firstDot + 1);
  }

  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

  return TimeOfDay(hour: hour, minute: minute);
}

/// Formats a [TimeOfDay] as the `HH:mm:ss` `TimeSpan` shape the API expects.
String formatApiTimeOfDay(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}:00';

/// Parses a JSON number/string into a [Decimal], never a `double`.
/// Returns null when the value is missing or unparseable.
Decimal? parseDecimal(Object? raw) {
  if (raw == null) return null;
  if (raw is Decimal) return raw;
  if (raw is num) return Decimal.parse(raw.toString());
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return Decimal.tryParse(trimmed);
  }
  return null;
}
