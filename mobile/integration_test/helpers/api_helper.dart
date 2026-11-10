import 'dart:convert';
import 'dart:io';

import 'test_config.dart';

/// Thin HTTP helper for making direct API calls from within integration tests.
///
/// Used for two purposes:
///   1. Querying state when coordinating two-simulator flows — e.g. the
///      homeowner test polls until the tradie simulator has accepted the offer.
///   2. Asserting backend state that isn't visible in the UI (e.g. job status).
///   3. Self-seeding fixtures — creating jobs, dispatching offers, uploading
///      receipts and verifying payments so each test controls its own state
///      instead of relying on pre-seeded data (see helpers/fixture_helper.dart).
class ApiHelper {
  ApiHelper._();

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// Returns a JWT for [email]/[password]. Throws on failure.
  static Future<String> getToken(String email, String password) async {
    final body = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    final token = body['token'] as String?;
    if (token == null) throw Exception('Login failed for $email: $body');
    return token;
  }

  static Future<String> get homeownerToken =>
      getToken(kHomeownerEmail, kHomeownerPassword);

  static Future<String> get tradieToken =>
      getToken(kTradieEmail, kTradiePassword);

  static Future<String> get staffToken =>
      getToken(kStaffEmail, kStaffPassword);

  // ── Jobs ───────────────────────────────────────────────────────────────────

  /// Creates a job as the homeowner. Returns the new job's ID.
  static Future<int> createJob(
    String token, {
    required String title,
    int serviceId = 1,
    double latitude = -36.8485,
    double longitude = 174.7633,
    int hours = 2,
    double hourlyRate = 85.50,
    String urgency = 'Medium',
  }) async {
    final body = await _post('/jobs', {
      'title': title,
      'description': 'Integration-test fixture job.',
      'urgency': urgency,
      'latitude': latitude,
      'longitude': longitude,
      'address': '1 Test St, Auckland',
      'serviceId': serviceId,
      'scheduledStartUtc':
          DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(),
      'hours': hours,
      'hourlyRate': hourlyRate,
    }, token: token);
    final id = body['id'] as int?;
    if (id == null) throw Exception('createJob failed: $body');
    return id;
  }

  /// Returns the current status string for [jobId].
  static Future<String> getJobStatus(int jobId, String token) async {
    final body = await _get('/jobs/$jobId', token: token);
    return body['status'] as String;
  }

  /// Kicks off sequential offer dispatch for a Requested job (homeowner only).
  static Future<void> dispatchMatch(int jobId, String token) =>
      _post('/jobs/$jobId/match', const {}, token: token);

  /// Returns the pending offer for [jobId] as seen by the tradie token,
  /// or null if there is none (HTTP 204).
  static Future<Map<String, dynamic>?> getPendingOffer(
      int jobId, String token) async {
    final client = HttpClient();
    try {
      final req = await client
          .getUrl(Uri.parse('$kApiBaseUrl/api/jobs/$jobId/offers/pending'));
      req.headers.set('Authorization', 'Bearer $token');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      if (resp.statusCode == 204) return null;
      final raw = await resp.transform(utf8.decoder).join();
      return jsonDecode(raw) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// Tradie responds 'Accepted' or 'Declined' to a pending offer.
  static Future<void> respondToOffer(
          int jobId, int offerId, String response, String token) =>
      _post('/jobs/$jobId/offers/$offerId/respond', {'response': response},
          token: token);

  // ── Lifecycle transitions ──────────────────────────────────────────────────

  static Future<void> checkIn(int jobId, String tradieToken) =>
      _post('/jobs/$jobId/check-in', const {}, token: tradieToken);

  static Future<void> checkOut(int jobId, String tradieToken) =>
      _post('/jobs/$jobId/check-out', const {}, token: tradieToken);

  static Future<void> confirmCompletion(int jobId, String homeownerToken) =>
      _post('/jobs/$jobId/confirm', const {}, token: homeownerToken);

  /// Sends a chat message on [jobId] as whoever owns [token].
  static Future<void> sendMessage(int jobId, String token, String content) =>
      _post('/jobs/$jobId/messages', {'content': content}, token: token);

  /// Full job payload for [jobId] as seen by [token]'s owner.
  static Future<Map<String, dynamic>> getJob(int jobId, String token) =>
      _get('/jobs/$jobId', token: token);

  // ── Payments ───────────────────────────────────────────────────────────────

  /// Opens/returns the payment for [jobId] (homeowner token).
  static Future<Map<String, dynamic>> getPayment(
          int jobId, String homeownerToken) =>
      _get('/jobs/$jobId/payment', token: homeownerToken);

  /// Uploads a PNG receipt. Moves the job to PaymentReview.
  ///
  /// The server rejects receipt bytes already seen on another payment, so a
  /// unique marker is appended to each upload.
  static Future<void> uploadReceipt(int jobId, String homeownerToken) async {
    // Smallest valid PNG (1x1 transparent) + a unique suffix so the server's
    // receipt dedupe doesn't reject it as a re-used file.
    final png = [
      ...base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='),
      ...utf8.encode('|fixo-test-${DateTime.now().microsecondsSinceEpoch}'),
    ];
    await _postMultipart(
        '/jobs/$jobId/payment/upload-receipt', 'receipt', png, 'receipt.png',
        'image/png', token: homeownerToken);
  }

  /// Staff verifies a submitted payment — job moves to Booked.
  static Future<void> verifyPayment(int paymentId, String staffToken) =>
      _post('/admin/payments/$paymentId/verify', const {}, token: staffToken);

  // ── Profile ────────────────────────────────────────────────────────────────

  /// Sets a tradie's IsAvailable flag (used to park competing tradies so the
  /// test tradie deterministically receives offers).
  static Future<void> setAvailability(
          String email, String password, bool available) =>
      getToken(email, password).then((token) =>
          _post('/profile/availability', {'available': available},
              token: token));

  // ── Generic ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _get(
    String path, {
    String? token,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse('$kApiBaseUrl/api$path'));
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final raw = await resp
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      _throwIfError(resp.statusCode, raw, 'GET $path');
      return raw.isNotEmpty
          ? jsonDecode(raw) as Map<String, dynamic>
          : <String, dynamic>{};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('$kApiBaseUrl/api$path'));
      req.headers.contentType = ContentType.json;
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      req.write(jsonEncode(payload));
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final raw = await resp
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      _throwIfError(resp.statusCode, raw, 'POST $path');
      return raw.isNotEmpty
          ? jsonDecode(raw) as Map<String, dynamic>
          : <String, dynamic>{};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> _postMultipart(
    String path,
    String field,
    List<int> bytes,
    String filename,
    String contentType, {
    String? token,
  }) async {
    final boundary = 'fixotest${DateTime.now().millisecondsSinceEpoch}';
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('$kApiBaseUrl/api$path'));
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      req.headers.contentType = ContentType('multipart', 'form-data',
          parameters: {'boundary': boundary});
      req.add([
        ...utf8.encode(
            '--$boundary\r\nContent-Disposition: form-data; name="$field"; filename="$filename"\r\nContent-Type: $contentType\r\n\r\n'),
        ...bytes,
        ...utf8.encode('\r\n--$boundary--\r\n'),
      ]);
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final raw = await resp
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      _throwIfError(resp.statusCode, raw, 'POST $path (multipart)');
      return raw.isNotEmpty
          ? jsonDecode(raw) as Map<String, dynamic>
          : <String, dynamic>{};
    } finally {
      client.close();
    }
  }

  static void _throwIfError(int statusCode, String body, String op) {
    if (statusCode >= 400) {
      throw Exception('ApiHelper $op → HTTP $statusCode: $body');
    }
  }
}
