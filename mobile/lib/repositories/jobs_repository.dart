import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/marketplace.dart';
import '../network/api_error.dart';
import 'profile_repository.dart';

/// Jobs + matching repository.
///
/// Wires directly to the live backend:
///   POST   /api/jobs
///   GET    /api/jobs?status=&page=&pageSize=
///   GET    /api/jobs/:id
///   PATCH  /api/jobs/:id
///   DELETE /api/jobs/:id
///   POST   /api/jobs/:id/match   (trigger matching run)
///   GET    /api/jobs/:id/matches (fetch match list)
///   POST   /api/jobs/:id/request {tradieId, message?}  (v1.7 direct request)
///   POST   /api/jobs/:id/requests {tradieId}           (legacy direct request)
///   GET    /api/jobs/:id/tradies?sort=&verified=&insured=&availableNow=
///   POST   /api/jobs/:id/accept
///   POST   /api/jobs/:id/decline
///   GET    /api/jobs/:id/offers/pending     (tradie's own pending offer)
///   POST   /api/jobs/:id/offers/:offerId/respond
///   POST   /api/jobs/:id/photos  (multipart, up to 5 files)
///   POST   /api/jobs/:id/check-out {finalHours, notes?}  (v1.7)
///   POST   /api/jobs/:id/approve {note?}                 (v1.7)
///   GET    /api/jobs/:id/adjustments                     (v1.7)
///   POST   /api/jobs/:id/adjustments                     (v1.7)
///   POST   /api/jobs/:id/adjustments/:adjId/respond      (v1.7)
///   POST   /api/jobs/:id/adjustments/:adjId/withdraw     (v1.7)
///   GET    /api/jobs/:id/quotes                          (v1.7)
///   POST   /api/jobs/:id/quotes                          (v1.7)
///   POST   /api/jobs/:id/quotes/:quoteId/accept          (v1.7)
class JobsRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  JobsRepository(this._dio, this._storage);

  Options _authOptions(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<String?> _token() => _storage.read(key: 'jwt_token');

  // ── Homeowner: list my jobs ────────────────────────────────────────────────

  Future<List<Job>> getMyJobs({String? status}) async {
    final token = await _token();
    if (token == null) return const [];
    final res = await _dio.get(
      '/api/jobs',
      queryParameters: {'status': ?status, 'pageSize': '50'},
      options: _authOptions(token),
    );
    final items = res.data['items'] as List?;
    return items
            ?.map((j) => Job.fromJson(j as Map<String, dynamic>))
            .toList() ??
        const [];
  }

  // ── Tradie: list incoming/active jobs ─────────────────────────────────────

  Future<List<Job>> getTradieJobs() async {
    final token = await _token();
    if (token == null) return const [];
    final res = await _dio.get(
      '/api/jobs',
      queryParameters: {'pageSize': '50'},
      options: _authOptions(token),
    );
    final items = res.data['items'] as List?;
    return items
            ?.map((j) => Job.fromJson(j as Map<String, dynamic>))
            .toList() ??
        const [];
  }

  // ── Tradie: available jobs board (plan 10 Q7.4 / Q7.10) ───────────────────

  Future<List<AvailableJob>> getAvailableJobs({
    int page = 1,
    int pageSize = 20,
  }) async {
    final token = await _token();
    if (token == null) return const [];
    final res = await _dio.get(
      '/api/tradie/available-jobs',
      queryParameters: {'page': page, 'pageSize': pageSize},
      options: _authOptions(token),
    );
    final items = res.data['items'] as List?;
    return items
            ?.whereType<Map<String, dynamic>>()
            .map(AvailableJob.fromJson)
            .toList() ??
        const [];
  }

  // ── GET /api/jobs/:id ────────────────────────────────────────────────────

  /// Fetches a single job. Returns null on 404 / no token.
  /// Used by the tradie request-detail screen.
  Future<Job?> getJobById(String jobId) async {
    final token = await _token();
    if (token == null) return null;
    try {
      final res = await _dio.get(
        '/api/jobs/$jobId',
        options: _authOptions(token),
      );
      return Job.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── GET /api/jobs/:id/contact ──────────────────────────────────────────────
  // V15-15: counterparty contact, Booked+ and participant-only server-side.
  // Returns null when not authorized, not yet contactable, or on failure —
  // callers must hide contact actions rather than fabricate them.

  Future<JobContact?> getJobContact(String jobId) async {
    try {
      final token = await _token();
      if (token == null) return null;
      final res = await _dio.get(
        '/api/jobs/$jobId/contact',
        options: _authOptions(token),
      );
      return JobContact.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── DELETE /api/jobs/:id ───────────────────────────────────────────────────

  /// Cancels a job (homeowner cancel before confirm). Returns true on success.
  Future<bool> cancelJob(String jobId) async {
    final token = await _token();
    if (token == null) return false;
    try {
      await _dio.delete('/api/jobs/$jobId', options: _authOptions(token));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── POST /api/jobs/:id/cancel ─────────────────────────────────────────────
  // P6-03: Cancel with reason code and optional notes.

  /// Cancels a job with a [reasonCode] (snake_case enum value, e.g.
  /// `homeowner_changed_mind`) and optional [notes].
  /// Returns true on success, false on failure (e.g. terminal status).
  Future<bool> cancelJobWithReason(
    String jobId, {
    required String reasonCode,
    String? notes,
  }) async {
    final token = await _token();
    if (token == null) return false;
    try {
      await _dio.post(
        '/api/jobs/$jobId/cancel',
        data: {
          'reasonCode': reasonCode,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
        options: _authOptions(token),
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        '[Jobs] cancelJobWithReason failed: ${friendlyDioError(e, tag: "Cancel")}',
      );
      return false;
    }
  }

  // ── POST /api/jobs ─────────────────────────────────────────────────────────

  /// Posts a new job and returns the job ID as a string.
  Future<String> postJob(Map<String, dynamic> payload) async {
    final token = await _token();
    final res = await _dio.post(
      '/api/jobs',
      data: payload,
      options: token != null ? _authOptions(token) : null,
    );
    return (res.data['id'] as int).toString();
  }

  Future<List<ServiceOption>> getServiceCatalog() async {
    final token = await _token();
    if (token == null) return const [];
    final res = await _dio.get(
      '/api/tradie/services',
      options: _authOptions(token),
    );
    return (res.data as List?)
            ?.map(
              (item) => ServiceOption.fromJson(item as Map<String, dynamic>),
            )
            .toList() ??
        const [];
  }

  Future<List<ServiceRateOption>> searchServiceRates({
    required int serviceId,
    required double latitude,
    required double longitude,
  }) async {
    final token = await _token();
    if (token == null) return const [];
    final res = await _dio.get(
      '/api/services/search',
      queryParameters: {
        'serviceId': serviceId,
        'lat': latitude,
        'lng': longitude,
      },
      options: _authOptions(token),
    );
    return (res.data as List?)
            ?.map(
              (item) =>
                  ServiceRateOption.fromJson(item as Map<String, dynamic>),
            )
            .toList() ??
        const [];
  }

  // ── POST /api/jobs/:id/photos (multipart) ─────────────────────────────────

  /// Uploads [filePaths] to the backend photo endpoint.
  /// Returns the list of photo URLs returned by the server.
  Future<List<String>> uploadPhotos(
    String jobId,
    List<String> filePaths,
  ) async {
    final token = await _token();
    if (token == null) throw StateError('Please sign in again.');
    final existing = await _dio.get(
      '/api/jobs/$jobId',
      options: _authOptions(token),
    );
    final photos = (existing.data['photos'] as List).cast<Map>();
    final urls = <String>[];
    for (var index = 0; index < filePaths.length; index++) {
      final file = File(filePaths[index]);
      if (await file.length() > 10 * 1024 * 1024) {
        throw StateError('Photo exceeds 10 MB.');
      }
      final bytes = await file.openRead(0, 32).first;
      final jpeg =
          bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      final png =
          bytes.length >= 8 &&
          bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
      final heic =
          bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp' &&
          [
            'heic',
            'heix',
            'hevc',
            'hevx',
            'mif1',
            'msf1',
          ].contains(String.fromCharCodes(bytes.sublist(8, 12)));
      if (!jpeg && !png && !heic) {
        throw StateError('Choose a JPEG, PNG or HEIC image.');
      }
      final extension = jpeg
          ? 'jpg'
          : png
          ? 'png'
          : 'heic';
      final filename = 'fixo-$jobId-photo-$index.$extension';
      final uploaded = photos.where(
        (photo) => photo['originalFileName'] == filename,
      );
      if (uploaded.isNotEmpty) {
        urls.add(uploaded.first['url'] as String);
        continue;
      }
      final formData = FormData.fromMap({
        'files': [
          await MultipartFile.fromFile(
            file.path,
            filename: filename,
            contentType: DioMediaType.parse(
              jpeg
                  ? 'image/jpeg'
                  : png
                  ? 'image/png'
                  : 'image/heic',
            ),
          ),
        ],
      });
      final response = await _dio.post(
        '/api/jobs/$jobId/photos',
        data: formData,
        options: _authOptions(token),
      );
      final uploadedPhotos = response.data as List;
      if (uploadedPhotos.length != 1) {
        throw StateError('Photo upload was not confirmed.');
      }
      urls.add(uploadedPhotos.single['url'] as String);
    }
    return urls;
  }

  // ── POST /api/jobs/:id/match ──────────────────────────────────────────────

  /// Kicks off sequential matching. The server replies 202 immediately and
  /// drives the run itself — offers, timeouts, and broadening all happen
  /// server-side, and progress arrives over SignalR `OfferLifecycleEvent`.
  /// There is deliberately no result list here; the homeowner watches the
  /// hub instead of polling (P3-03 / P3-09).
  ///
  /// Returns false when the request could not be started (e.g. the job is no
  /// longer in `Requested`).
  Future<bool> triggerMatch(String jobId) async {
    final token = await _token();
    if (token == null) return false;
    try {
      await _dio.post('/api/jobs/$jobId/match', options: _authOptions(token));
      return true;
    } on DioException catch (e) {
      debugPrint(
        '[Jobs] triggerMatch failed: ${friendlyDioError(e, tag: 'Match')}',
      );
      return false;
    }
  }

  // ── GET /api/jobs/:id/matches ──────────────────────────────────────────────

  /// Returns matches from the backend. Empty list means no tradies found —
  /// callers show the empty state (no stub data; keeps UI factual).
  Future<List<TradieMatch>> getMatches(String jobId) async {
    final token = await _token();
    try {
      final res = await _dio.get(
        '/api/jobs/$jobId/matches',
        options: token != null ? _authOptions(token) : null,
      );
      final matches = res.data['matches'] as List?;
      return matches
              ?.map((m) => TradieMatch.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [];
    } catch (_) {
      return const [];
    }
  }

  // ── POST /api/jobs/:id/requests ────────────────────────────────────────────

  /// Homeowner selects a specific tradie. Returns true only when the server
  /// accepted the request — the caller must not navigate on false.
  Future<bool> requestTradie(String jobId, String tradieId) async {
    final token = await _token();
    try {
      await _dio.post(
        '/api/jobs/$jobId/requests',
        data: {'tradieId': tradieId},
        options: token != null ? _authOptions(token) : null,
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        '[Jobs] requestTradie failed: ${friendlyDioError(e, tag: 'Request')}',
      );
      return false;
    }
  }

  // ── POST /api/jobs/:id/accept ──────────────────────────────────────────────

  Future<void> acceptJob(String jobId) async {
    final token = await _token();
    try {
      await _dio.post(
        '/api/jobs/$jobId/accept',
        options: token != null ? _authOptions(token) : null,
      );
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  // ── POST /api/jobs/:id/decline ─────────────────────────────────────────────

  Future<void> declineJob(String jobId) async {
    final token = await _token();
    try {
      await _dio.post(
        '/api/jobs/$jobId/decline',
        options: token != null ? _authOptions(token) : null,
      );
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  // ── POST /api/jobs/:id/check-in ─────────────────────────────────────────────
  // P5-02: Tradie checks in - transitions job to InProgress

  Future<bool> checkIn(String jobId) async {
    final token = await _token();
    if (token == null) return false;
    try {
      await _dio.post(
        '/api/jobs/$jobId/check-in',
        options: _authOptions(token),
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        '[Jobs] checkIn failed: ${friendlyDioError(e, tag: 'CheckIn')}',
      );
      return false;
    }
  }

  // ── POST /api/jobs/:id/check-out ────────────────────────────────────────────
  // v1.7 (contract #7): tradie submits the hours actually worked; the server
  // computes labour + adjustments and returns the itemised summary. The job
  // transitions to AwaitingConfirmation so the homeowner can review & approve.

  /// Submits the check-out. Returns the server's own [CheckOutSummary] —
  /// the caller renders it verbatim, never recomputes. Returns null on
  /// failure (stale status / network).
  Future<CheckOutSummary?> checkOut(
    String jobId, {
    required double finalHours,
    String? notes,
  }) async {
    final token = await _token();
    if (token == null) return null;
    try {
      final res = await _dio.post(
        '/api/jobs/$jobId/check-out',
        data: {
          'finalHours': finalHours,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
        options: _authOptions(token),
      );
      return CheckOutSummary.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint(
        '[Jobs] checkOut failed: ${friendlyDioError(e, tag: 'CheckOut')}',
      );
      return null;
    }
  }

  // ── POST /api/jobs/:id/approve ──────────────────────────────────────────────
  // v1.7 (contract #8): the homeowner approves the itemised completion
  // summary; the job moves to AwaitingPayment. 409 while an adjustment is
  // still pending — the server's message is surfaced to the caller.

  /// Approves the completion. Throws [ProfileApiException] with the server's
  /// message on failure (e.g. "adjustments are still pending") so the caller
  /// can show the real reason.
  Future<void> approveJob(String jobId, {String? note}) async {
    final token = await _token();
    if (token == null) {
      throw const ProfileApiException('Please sign in again.');
    }
    try {
      await _dio.post(
        '/api/jobs/$jobId/approve',
        data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
        options: _authOptions(token),
      );
    } on DioException catch (e) {
      throw ProfileApiException(friendlyDioError(e, tag: 'Approve'));
    }
  }

  // ── GET /api/jobs/:id/tradies ───────────────────────────────────────────────
  // v1.7 (contract #2): the Choose-a-Tradie list. The server owns ranking
  // ("best" = score) and filtering; hourlyRate is the job's-service final
  // consumer price with the GST status attached (D8).

  Future<List<TradieListEntry>> getTradieList(
    String jobId, {
    String sort = 'best',
    bool? verified,
    bool? insured,
    bool? availableNow,
  }) async {
    final token = await _token();
    if (token == null) return const [];
    final res = await _dio.get(
      '/api/jobs/$jobId/tradies',
      queryParameters: {
        'sort': sort,
        if (verified == true) 'verified': 'true',
        if (insured == true) 'insured': 'true',
        if (availableNow == true) 'availableNow': 'true',
      },
      options: _authOptions(token),
    );
    final items = res.data as List?;
    return items
            ?.map((t) => TradieListEntry.fromJson(t as Map<String, dynamic>))
            .toList() ??
        const [];
  }

  // ── POST /api/jobs/:id/request ──────────────────────────────────────────────
  // v1.7 (contract #3): direct request for a specific tradie with an optional
  // pre-acceptance message (D3 — the only contact channel before Booked).
  // The server replies 202 with the created offer; 409 means a conflict
  // (pending request exists, tradie already asked, ...) and its message is
  // surfaced to the caller.

  /// Sends a direct request. Returns the created [JobOffer] on success.
  /// Throws [ProfileApiException] with the server's message on conflict or
  /// failure — callers must not navigate on a throw.
  Future<JobOffer> requestTradieForJob(
    String jobId,
    String tradieId, {
    String? message,
  }) async {
    final token = await _token();
    if (token == null) {
      throw const ProfileApiException('Please sign in again.');
    }
    try {
      final res = await _dio.post(
        '/api/jobs/$jobId/request',
        data: {
          'tradieId': tradieId,
          if (message != null && message.trim().isNotEmpty)
            'message': message.trim(),
        },
        options: _authOptions(token),
      );
      return JobOffer.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ProfileApiException(friendlyDioError(e, tag: 'Request'));
    }
  }

  // ── v1.7 adjustments (contract #9 / #10) ────────────────────────────────────

  /// Lists every price adjustment proposed on [jobId].
  Future<List<JobAdjustment>> getAdjustments(String jobId) async {
    final token = await _token();
    if (token == null) return const [];
    try {
      final res = await _dio.get(
        '/api/jobs/$jobId/adjustments',
        options: _authOptions(token),
      );
      final items = res.data as List?;
      return items
              ?.map((a) => JobAdjustment.fromJson(a as Map<String, dynamic>))
              .toList() ??
          const [];
    } on DioException catch (e) {
      debugPrint(
        '[Jobs] getAdjustments failed: '
        '${friendlyDioError(e, tag: 'Adjustments')}',
      );
      return const [];
    }
  }

  /// Tradie proposes an extra cost. Throws [ProfileApiException] with the
  /// server's message on validation/conflict failure.
  ///
  /// [evidenceFileKey] is a pre-uploaded blob key. There is no generic file
  /// upload endpoint in the current API surface (only job photos), so the
  /// mobile UI keeps the receipt attach optional and this argument is only
  /// sent when the caller actually holds a blob key.
  Future<void> createAdjustment(
    String jobId, {
    required String kind,
    required String description,
    required Decimal amount,
    String? evidenceFileKey,
  }) async {
    final token = await _token();
    if (token == null) {
      throw const ProfileApiException('Please sign in again.');
    }
    try {
      await _dio.post(
        '/api/jobs/$jobId/adjustments',
        data: {
          'kind': kind,
          'description': description,
          'amount': amount.toString(),
          if (evidenceFileKey != null && evidenceFileKey.isNotEmpty)
            'evidenceFileKey': evidenceFileKey,
        },
        options: _authOptions(token),
      );
    } on DioException catch (e) {
      throw ProfileApiException(friendlyDioError(e, tag: 'Adjustment'));
    }
  }

  /// Homeowner approves/declines a proposed adjustment
  /// (contract #10). Throws [ProfileApiException] with the server's message.
  Future<void> respondToAdjustment(
    String jobId,
    String adjustmentId, {
    required bool approve,
    String? note,
  }) async {
    final token = await _token();
    if (token == null) {
      throw const ProfileApiException('Please sign in again.');
    }
    try {
      await _dio.post(
        '/api/jobs/$jobId/adjustments/$adjustmentId/respond',
        data: {
          'approve': approve,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
        options: _authOptions(token),
      );
    } on DioException catch (e) {
      throw ProfileApiException(friendlyDioError(e, tag: 'Adjustment'));
    }
  }

  /// Tradie withdraws their own still-pending proposal (contract #10).
  Future<void> withdrawAdjustment(String jobId, String adjustmentId) async {
    final token = await _token();
    if (token == null) {
      throw const ProfileApiException('Please sign in again.');
    }
    try {
      await _dio.post(
        '/api/jobs/$jobId/adjustments/$adjustmentId/withdraw',
        options: _authOptions(token),
      );
    } on DioException catch (e) {
      throw ProfileApiException(friendlyDioError(e, tag: 'Adjustment'));
    }
  }

  // ── v1.7 quotes (contract #11–#13) ──────────────────────────────────────────

  /// Lists the quotes submitted on a project job.
  Future<List<Quote>> getQuotes(String jobId) async {
    final token = await _token();
    if (token == null) return const [];
    try {
      final res = await _dio.get(
        '/api/jobs/$jobId/quotes',
        options: _authOptions(token),
      );
      final items = res.data as List?;
      return items
              ?.map((q) => Quote.fromJson(q as Map<String, dynamic>))
              .toList() ??
          const [];
    } on DioException catch (e) {
      debugPrint(
        '[Jobs] getQuotes failed: ${friendlyDioError(e, tag: 'Quotes')}',
      );
      return const [];
    }
  }

  /// Tradie submits a quote (contract #12) while a QuoteRequest offer is
  /// pending. [gstIncluded] must match the tradie's GST registration — the
  /// backend enforces the rule. Throws [ProfileApiException] with the
  /// server's message on failure.
  Future<void> createQuote(String jobId, Map<String, dynamic> payload) async {
    final token = await _token();
    if (token == null) {
      throw const ProfileApiException('Please sign in again.');
    }
    try {
      await _dio.post(
        '/api/jobs/$jobId/quotes',
        data: payload,
        options: _authOptions(token),
      );
    } on DioException catch (e) {
      throw ProfileApiException(friendlyDioError(e, tag: 'Quote'));
    }
  }

  /// Homeowner accepts a quote (contract #13). Amounts ≥ NZD 30,000 require
  /// the written-contract confirmation — retry with
  /// [confirmWrittenContract] = true after the 409. Returns the parsed 409
  /// body so the caller can show the threshold notice.
  Future<QuoteAcceptResult> acceptQuote(
    String jobId,
    String quoteId, {
    required bool confirmWrittenContract,
  }) async {
    final token = await _token();
    if (token == null) {
      return const QuoteAcceptResult.signedOut();
    }
    try {
      await _dio.post(
        '/api/jobs/$jobId/quotes/$quoteId/accept',
        data: {'confirmWrittenContract': confirmWrittenContract},
        options: _authOptions(token),
      );
      return const QuoteAcceptResult.accepted();
    } on DioException catch (e) {
      final body = e.response?.data;
      final requiresContract =
          body is Map && body['requiresWrittenContractConfirmation'] == true;
      if (requiresContract) {
        return QuoteAcceptResult.needsWrittenContract(
          threshold: body['threshold']?.toString(),
          message: body['message']?.toString(),
        );
      }
      return QuoteAcceptResult.failure(friendlyDioError(e, tag: 'Quote'));
    }
  }

  // ── POST /api/jobs/:id/confirm ──────────────────────────────────────────────
  // P5-02: Homeowner confirms completion - transitions job to Completed

  Future<bool> confirmCompletion(String jobId) async {
    final token = await _token();
    if (token == null) return false;
    try {
      await _dio.post('/api/jobs/$jobId/confirm', options: _authOptions(token));
      return true;
    } on DioException catch (e) {
      debugPrint(
        '[Jobs] confirmCompletion failed: ${friendlyDioError(e, tag: 'Confirm')}',
      );
      return false;
    }
  }

  // ── GET /api/jobs/:id/offers/pending ───────────────────────────────────────

  /// The calling tradie's pending offer for [jobId], or null when they have
  /// none (never offered, already answered, or already timed out). The
  /// request-detail screen counts down against `expiresAtUtc` (P3-08).
  Future<JobOffer?> getPendingOffer(String jobId) async {
    final token = await _token();
    if (token == null) return null;
    try {
      final res = await _dio.get(
        '/api/jobs/$jobId/offers/pending',
        options: _authOptions(token),
      );
      if (res.statusCode == 204 || res.data == null) return null;
      return JobOffer.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 204 arrives as a null body on some Dio versions.
      if (e.response?.statusCode == 204) return null;
      rethrow;
    }
  }

  // ── POST /api/jobs/:id/offers/:offerId/respond ─────────────────────────────

  /// Responds to a pending offer with 'Accepted' or 'Declined'. Declining
  /// makes the server dispatch the next ranked tradie (P3-07).
  /// Returns false when the offer was already answered (409) or the request
  /// failed — callers refresh the pending offer rather than guessing.
  Future<bool> respondToOffer(
    String jobId,
    String offerId, {
    required String response,
  }) async {
    final token = await _token();
    if (token == null) return false;
    try {
      await _dio.post(
        '/api/jobs/$jobId/offers/$offerId/respond',
        data: {'response': response},
        options: _authOptions(token),
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        '[Jobs] respondToOffer failed: ${friendlyDioError(e, tag: 'Offers')}',
      );
      return false;
    }
  }

  // ── P7: Disputes & No-Shows ───────────────────────────────────────────────

  /// Opens a new dispute for [jobId] with a [reason] and [details].
  /// Returns the new dispute ID on success.
  ///
  /// Throws [ProfileApiException] with the server's message on failure —
  /// "a dispute is already open for this job" and validation rejections are
  /// facts the caller should show, not collapse into a generic error.
  Future<String> openDispute(
    String jobId,
    String reason,
    String details,
  ) async {
    final token = await _token();
    if (token == null) {
      throw const ProfileApiException('Please sign in again.');
    }
    try {
      final res = await _dio.post(
        '/api/disputes',
        data: {'jobId': jobId, 'reason': reason, 'details': details},
        options: _authOptions(token),
      );
      final id = res.data['id']?.toString();
      if (id == null) {
        throw const ProfileApiException('Could not open the dispute.');
      }
      return id;
    } on DioException catch (e) {
      throw ProfileApiException(friendlyDioError(e, tag: 'Dispute'));
    }
  }

  /// Uploads evidence (photos and/or text) to an open dispute.
  /// Throws [ProfileApiException] with the server's message on failure.
  Future<void> uploadDisputeEvidence(
    String disputeId,
    List<String> filePaths,
    String? textNotes,
  ) async {
    final token = await _token();
    if (token == null) {
      throw const ProfileApiException('Please sign in again.');
    }
    try {
      if (textNotes != null && textNotes.isNotEmpty) {
        await _dio.post(
          '/api/disputes/$disputeId/evidence/text',
          data: {'textContent': textNotes},
          options: _authOptions(token),
        );
      }
      if (filePaths.isNotEmpty) {
        final formData = FormData.fromMap({
          'files': [
            for (final path in filePaths) await MultipartFile.fromFile(path),
          ],
        });
        await _dio.post(
          '/api/disputes/$disputeId/evidence/files',
          data: formData,
          options: _authOptions(token),
        );
      }
    } on DioException catch (e) {
      throw ProfileApiException(friendlyDioError(e, tag: 'Dispute'));
    }
  }

  /// Reports a no-show for [jobId]. Homeowners can pass [action] as "reassign" or "cancel".
  Future<bool> reportNoShow(String jobId, {String? action}) async {
    final token = await _token();
    if (token == null) return false;
    try {
      await _dio.post(
        '/api/jobs/$jobId/no-show',
        data: action != null ? {'action': action} : {},
        options: _authOptions(token),
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        '[Jobs] reportNoShow failed: ${friendlyDioError(e, tag: "NoShow")}',
      );
      return false;
    }
  }
}

/// Outcome of POST /api/jobs/:id/quotes/:quoteId/accept (v1.7 contract #13).
/// Large quotes (≥ NZD 30,000) come back as [requiresWrittenContract] with
/// the server's threshold + message; the caller shows the notice and retries
/// with `confirmWrittenContract: true`.
class QuoteAcceptResult {
  final bool accepted;
  final bool requiresWrittenContract;

  /// True when the caller had no session token — treated like a failure.
  final bool signedOut;

  /// Server-supplied threshold (e.g. "30000") and human message from the 409.
  final String? threshold;
  final String? message;

  /// True on a generic failure; [message] carries the reason.
  final bool failed;

  const QuoteAcceptResult._({
    required this.accepted,
    required this.requiresWrittenContract,
    required this.signedOut,
    required this.failed,
    this.threshold,
    this.message,
  });

  const QuoteAcceptResult.accepted()
    : this._(
        accepted: true,
        requiresWrittenContract: false,
        signedOut: false,
        failed: false,
      );

  const QuoteAcceptResult.needsWrittenContract({
    String? threshold,
    String? message,
  }) : this._(
         accepted: false,
         requiresWrittenContract: true,
         signedOut: false,
         failed: false,
         threshold: threshold,
         message: message,
       );

  const QuoteAcceptResult.signedOut()
    : this._(
        accepted: false,
        requiresWrittenContract: false,
        signedOut: true,
        failed: true,
      );

  const QuoteAcceptResult.failure(String reason)
    : this._(
        accepted: false,
        requiresWrittenContract: false,
        signedOut: false,
        failed: true,
        message: reason,
      );
}
