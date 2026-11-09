import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/marketplace.dart';
import '../models/tradie_onboarding.dart';
import '../network/api_error.dart';

/// Raised when a tradie onboarding call fails, carrying copy that is safe
/// to show the user.
class ProfileApiException implements Exception {
  final String message;

  /// True when the API answered 403 — on `/api/tradie/*` that means the
  /// signed-in user has no `TradieProfile` row yet (still 1 for a tradie who
  /// has just registered), so callers can treat the resource as empty
  /// instead of surfacing an error.
  final bool isForbidden;

  const ProfileApiException(this.message, {this.isForbidden = false});

  @override
  String toString() => message;
}

class ProfileRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ProfileRepository(this._dio, this._storage);

  Future<Options> _authOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> getCurrentProfile() async {
    final response = await _dio.get(
      '/api/profile',
      options: await _authOptions(),
    );
    return response.data;
  }

  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    await _dio.put(
      '/api/profile',
      data: profileData,
      options: await _authOptions(),
    );
  }

  // P10-18: Mobile — Tradie Availability Toggle
  Future<void> updateAvailability(bool isAvailable) async {
    try {
      await _dio.post(
        '/api/profile/availability',
        data: {'available': isAvailable},
        options: await _authOptions(),
      );
    } on DioException catch (e) {
      throw _fail(e, 'updateAvailability');
    }
  }

  // ── Safety: block & report (P8-02) ────────────────────────────────────────

  /// `POST /api/profile/block` — idempotent.
  Future<void> blockUser(String blockedUserId) async {
    try {
      await _dio.post(
        '/api/profile/block',
        data: {'blockedUserId': blockedUserId},
        options: await _authOptions(),
      );
    } on DioException catch (e) {
      throw _fail(e, 'blockUser');
    }
  }

  /// `DELETE /api/profile/block/:id`
  Future<void> unblockUser(String blockedUserId) async {
    try {
      await _dio.delete(
        '/api/profile/block/$blockedUserId',
        options: await _authOptions(),
      );
    } on DioException catch (e) {
      throw _fail(e, 'unblockUser');
    }
  }

  /// `POST /api/profile/report` — files an Abuse flag for staff triage.
  Future<void> reportUser(String reportedUserId, {String? reason}) async {
    try {
      await _dio.post(
        '/api/profile/report',
        data: {
          'reportedUserId': reportedUserId,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
        options: await _authOptions(),
      );
    } on DioException catch (e) {
      throw _fail(e, 'reportUser');
    }
  }

  // ── Tradie onboarding (P1-06 / P1-09) ─────────────────────────────────────
  //
  // All of these live behind `api/tradie` on the backend and 403 when the
  // signed-in user has no `TradieProfile` row. `PUT /api/profile` creates
  // that row as a side effect, so step 1 of the wizard must save first.

  /// Builds the exception for a failed tradie call, flagging 403 so callers
  /// can tell "no TradieProfile yet" apart from a real failure.
  ProfileApiException _fail(DioException e, String tag) => ProfileApiException(
    friendlyDioError(e, tag: 'ProfileRepository.$tag'),
    isForbidden: e.response?.statusCode == 403,
  );

  /// `GET /api/tradie/services` — the trade catalog to pick rates from.
  Future<List<TradieService>> getServiceCatalog() async {
    try {
      final res = await _dio.get(
        '/api/tradie/services',
        options: await _authOptions(),
      );
      final list = (res.data as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(TradieService.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ProfileApiException(
        friendlyDioError(e, tag: 'ProfileRepository.getServiceCatalog'),
      );
    }
  }

  /// `GET /api/tradie/schedule` — the tradie's weekly availability.
  Future<List<TradieScheduleSlot>> getSchedule() async {
    try {
      final res = await _dio.get(
        '/api/tradie/schedule',
        options: await _authOptions(),
      );
      return _scheduleFrom(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return [];
      throw _fail(e, 'getSchedule');
    }
  }

  /// `POST /api/tradie/schedule` — full replacement of the weekly set.
  Future<List<TradieScheduleSlot>> updateSchedule(
    List<TradieScheduleSlot> slots,
  ) async {
    try {
      final res = await _dio.post(
        '/api/tradie/schedule',
        data: {
          'schedule': [for (final s in slots) s.toJson()],
        },
        options: await _authOptions(),
      );
      return _scheduleFrom(res.data);
    } on DioException catch (e) {
      throw _fail(e, 'updateSchedule');
    }
  }

  /// `GET /api/tradie/rates` — current per-service hourly rates.
  Future<List<TradieRateEntry>> getRates() async {
    try {
      final res = await _dio.get(
        '/api/tradie/rates',
        options: await _authOptions(),
      );
      return _ratesFrom(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return [];
      throw _fail(e, 'getRates');
    }
  }

  /// `POST /api/tradie/rates` — full replacement of the tradie's rates.
  Future<List<TradieRateEntry>> updateRates(List<TradieRateEntry> rates) async {
    try {
      final res = await _dio.post(
        '/api/tradie/rates',
        data: {
          'rates': [for (final r in rates) r.toInputJson()],
        },
        options: await _authOptions(),
      );
      return _ratesFrom(res.data);
    } on DioException catch (e) {
      throw _fail(e, 'updateRates');
    }
  }

  /// `GET /api/tradie/earnings` — the calling tradie's weekly net summary.
  /// Amounts arrive as server-computed decimal strings; no client-side totals.
  Future<TradieEarnings> getEarnings() async {
    try {
      final res = await _dio.get(
        '/api/tradie/earnings',
        options: await _authOptions(),
      );
      return TradieEarnings.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _fail(e, 'getEarnings');
    }
  }

  /// `GET /api/tradie/credentials` — previously uploaded documents, each
  /// with a short-lived SAS read URL for previewing.
  Future<List<TradieCredential>> getCredentials() async {
    try {
      final res = await _dio.get(
        '/api/tradie/credentials',
        options: await _authOptions(),
      );
      return _credentialsFrom(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return [];
      throw _fail(e, 'getCredentials');
    }
  }

  /// `POST /api/tradie/credentials` — multipart upload of one licence /
  /// insurance / certification document into the private blob container.
  /// The record is created with `Status = Pending`; an admin reviews it
  /// (P1-07) before the tradie counts as verified.
  Future<TradieCredential> uploadCredential({
    required String filePath,
    required String fileName,
    required CredentialKind kind,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        'type': kind.wireName,
      });
      final res = await _dio.post(
        '/api/tradie/credentials',
        data: form,
        options: await _authOptions(),
      );
      return TradieCredential.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    } on DioException catch (e) {
      throw _fail(e, 'uploadCredential');
    }
  }

  List<TradieScheduleSlot> _scheduleFrom(dynamic data) {
    final list = (data as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(TradieScheduleSlot.fromJson)
        .toList();
  }

  List<TradieCredential> _credentialsFrom(dynamic data) {
    final list = (data as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(TradieCredential.fromJson)
        .toList();
  }

  List<TradieRateEntry> _ratesFrom(dynamic data) {
    final list = (data as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(TradieRateEntry.fromJson)
        .toList();
  }
}
