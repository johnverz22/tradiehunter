import 'dart:io' show Platform, SocketException;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ─── Result types ─────────────────────────────────────────────────────────────

sealed class GoogleLoginResult {
  const GoogleLoginResult();
}

/// JWT stored — navigate to /home.
class GoogleLoginSuccess extends GoogleLoginResult {
  const GoogleLoginSuccess();
}

/// User dismissed the account picker — do nothing.
class GoogleLoginCancelled extends GoogleLoginResult {
  const GoogleLoginCancelled();
}

/// New Google account — navigate to /role-select with this userId.
class GoogleLoginRequiresRegistration extends GoogleLoginResult {
  final String userId;
  const GoogleLoginRequiresRegistration(this.userId);
}

// ─── Repository ───────────────────────────────────────────────────────────────

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  // google_sign_in 7.x singleton — initialized once in main.dart.
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  AuthRepository(this._dio, this._storage);

  // ── Email / password ────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    try {
      final response = await _dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });
      await _storeTokens(response.data);
    } on DioException catch (e) {
      debugPrint('[AuthRepository] login error: $e');
      throw Exception(_friendlyDioError(e));
    } catch (e) {
      debugPrint('[AuthRepository] login unexpected error: $e');
      throw Exception('Something went wrong. Please try again.');
    }
  }

  Future<void> register(String firstName, String lastName, String email,
      String password, int role) async {
    try {
      final response = await _dio.post('/api/auth/register', data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'role': role, // 1 = Homeowner, 2 = Tradie
      });
      await _storeTokens(response.data);
    } on DioException catch (e) {
      debugPrint('[AuthRepository] register error: $e');
      throw Exception(_friendlyDioError(e));
    } catch (e) {
      debugPrint('[AuthRepository] register unexpected error: $e');
      throw Exception('Something went wrong. Please try again.');
    }
  }

  // ── Google ──────────────────────────────────────────────────────────────────

  Future<GoogleLoginResult> loginWithGoogle() async {
    try {
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final String? idToken = googleUser.authentication.idToken;
      if (idToken == null) throw Exception('Google ID Token is null');

      final response =
          await _dio.post('/api/auth/google', data: {'idToken': idToken});

      if (response.data['requiresRegistration'] == true) {
        return GoogleLoginRequiresRegistration(
            response.data['userId'] as String);
      }

      await _storeTokens(response.data);
      return const GoogleLoginSuccess();
    } on GoogleSignInException catch (e) {
      debugPrint('[AuthRepository] Google sign-in exception: $e');
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const GoogleLoginCancelled();
      }
      throw Exception('Google sign-in failed. Please try again.');
    } on DioException catch (e) {
      debugPrint('[AuthRepository] Google login Dio error: $e');
      throw Exception(_friendlyDioError(e));
    } catch (e) {
      debugPrint('[AuthRepository] Google login unexpected error: $e');
      rethrow;
    }
  }

  /// Called from RoleSelectScreen after a new Google user picks their role.
  Future<void> completeRegistration(String userId, int role) async {
    try {
      final response = await _dio.patch(
        '/api/auth/complete-registration',
        queryParameters: {'userId': userId},
        data: {'role': role},
      );
      await _storeTokens(response.data);
    } on DioException catch (e) {
      debugPrint('[AuthRepository] completeRegistration error: $e');
      throw Exception(_friendlyDioError(e));
    } catch (e) {
      debugPrint('[AuthRepository] completeRegistration unexpected error: $e');
      throw Exception('Something went wrong. Please try again.');
    }
  }

  // ── FCM ─────────────────────────────────────────────────────────────────────

  /// Register (or refresh) an FCM device token with the backend.
  /// Called after every successful login / registration and on token refresh.
  Future<void> registerDeviceToken(String fcmToken) async {
    try {
      final jwt = await _storage.read(key: 'jwt_token');
      if (jwt == null) return;

      final platform = Platform.isAndroid ? 'Android' : 'iOS';
      await _dio.post(
        '/api/profile/device-token',
        data: {'token': fcmToken, 'platform': platform},
        options: Options(headers: {'Authorization': 'Bearer $jwt'}),
      );
    } catch (e) {
      // Non-fatal — retried on next launch via onTokenRefresh.
      debugPrint('[AuthRepository] FCM token registration failed: $e');
    }
  }

  // ── Logout ──────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
    await _googleSignIn.signOut();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<void> _storeTokens(Map<String, dynamic> data) async {
    await _storage.write(key: 'jwt_token', value: data['token'] as String);
    await _storage.write(
        key: 'refresh_token', value: data['refreshToken'] as String);
  }

  /// Translates a [DioException] into a short, user-friendly message.
  /// Full technical detail is always printed to the debug console first.
  String _friendlyDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "Can't reach the server. Check your connection and try again.";
      case DioExceptionType.connectionError:
        final inner = e.error;
        if (inner is SocketException) {
          return "Can't reach the server. Check your connection and try again.";
        }
        return 'Connection failed. Please try again.';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final body = e.response?.data;
        debugPrint('[AuthRepository] HTTP $status body: $body');
        return switch (status) {
          400 => _extractServerMessage(body) ??
              'Invalid details. Please check your input.',
          401 => 'Incorrect email or password.',
          409 => 'An account with this email already exists.',
          422 => _extractServerMessage(body) ?? 'Validation failed.',
          500 => 'Server error. Please try again later.',
          _ => 'Unexpected error ($status). Please try again.',
        };
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  /// Pulls a human-readable message from common ASP.NET Core error shapes.
  String? _extractServerMessage(dynamic body) {
    if (body == null) return null;

    // ── ASP.NET Identity errors: [{code, description}, ...]  ────────────────
    // Returned by UserManager.CreateAsync when password/policy rules fail.
    if (body is List && body.isNotEmpty) {
      final messages = body
          .whereType<Map>()
          .map((e) => e['description'] as String?)
          .whereType<String>()
          .toList();
      if (messages.isNotEmpty) return messages.join('\n');
    }

    if (body is Map) {
      // ── FluentValidation errors: {errors: {field: [msg, ...]}}  ───────────
      // Returned as ValidationProblemDetails by ASP.NET Core.
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final messages = errors.values
            .whereType<List>()
            .expand((l) => l)
            .whereType<String>()
            .toList();
        if (messages.isNotEmpty) return messages.join('\n');
      }

      // ── FluentValidation raw list: [{propertyName, errorMessage}, ...]  ───
      // Some FluentValidation setups return the raw ValidationFailure list.
      final errList = body['errors'];
      if (errList is List && errList.isNotEmpty) {
        final messages = errList
            .whereType<Map>()
            .map((e) => e['errorMessage'] as String?)
            .whereType<String>()
            .toList();
        if (messages.isNotEmpty) return messages.join('\n');
      }

      // ── Simple {message} or {title}  ──────────────────────────────────────
      final msg = body['message'] ?? body['title'];
      if (msg is String && msg.isNotEmpty) return msg;
    }

    return null;
  }
}
