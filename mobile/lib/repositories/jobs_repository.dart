import 'dart:io';

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
///   POST   /api/jobs/:id/requests {tradieId}
///   POST   /api/jobs/:id/accept
///   POST   /api/jobs/:id/decline
///   GET    /api/jobs/:id/offers/pending     (tradie's own pending offer)
///   POST   /api/jobs/:id/offers/:offerId/respond
///   POST   /api/jobs/:id/photos  (multipart, up to 5 files)
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
      queryParameters: {if (status != null) 'status': status, 'pageSize': '50'},
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
  // P5-02: Tradie checks out - transitions job to AwaitingConfirmation

  Future<bool> checkOut(String jobId) async {
    final token = await _token();
    if (token == null) return false;
    try {
      await _dio.post(
        '/api/jobs/$jobId/check-out',
        options: _authOptions(token),
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        '[Jobs] checkOut failed: ${friendlyDioError(e, tag: 'CheckOut')}',
      );
      return false;
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
