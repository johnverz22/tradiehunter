import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/payment.dart';
import '../network/api_error.dart';

/// Manual payment repository (P4-07).
///
/// Fixo has no payment gateway at this phase: the homeowner is shown transfer
/// instructions, pays out of band, and uploads the bank receipt for staff to
/// confirm. The server owns every rule (who may pay, whether the receipt has
/// been seen before, whether the job is still open) — this repository only
/// moves the bytes and turns failures into copy the screen can show.
class PaymentsRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  PaymentsRepository(this._dio, this._storage);

  Options _authOptions(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<String?> _token() => _storage.read(key: 'jwt_token');

  /// GET /api/jobs/{id}/payment — instructions plus current state.
  ///
  /// Safe to call repeatedly: the payment is opened server-side on the first
  /// call, not on every call.
  Future<PaymentStatus> getPayment(String jobId) async {
    final token = await _token();
    if (token == null) {
      throw const PaymentAccessException('Please sign in again.');
    }
    try {
      final res = await _dio.get(
        '/api/jobs/$jobId/payment',
        options: _authOptions(token),
      );
      return PaymentStatus.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw PaymentAccessException(friendlyDioError(e, tag: 'Payment'));
    }
  }

  /// POST /api/jobs/{id}/payment/upload-receipt — multipart image upload.
  ///
  /// The server re-hashes the file, refuses a receipt already used for another
  /// payment, and moves the job into the staff review queue, so this returning
  /// means the receipt is queued rather than paid.
  Future<PaymentStatus> uploadReceipt(String jobId, String filePath) async {
    final token = await _token();
    if (token == null) {
      throw const PaymentAccessException('Please sign in again.');
    }
    try {
      final formData = FormData.fromMap({
        'receipt': await MultipartFile.fromFile(filePath),
      });
      final res = await _dio.post(
        '/api/jobs/$jobId/payment/upload-receipt',
        data: formData,
        options: _authOptions(token),
      );
      return PaymentStatus.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw PaymentAccessException(friendlyDioError(
        e,
        tag: 'Payment',
        // 409 is the "job is not payable / this receipt was already used"
        // case, and the server's message is the useful one.
        statusOverrides: const {
          404: 'This job is no longer available for payment.',
        },
      ));
    }
  }
}

/// A payment request the server refused, carrying copy safe to show the user.
class PaymentAccessException implements Exception {
  final String message;
  const PaymentAccessException(this.message);

  @override
  String toString() => message;
}
