import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../network/api_error.dart';

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

/// New Google account — navigate to /role-select with this userId and the
/// one-time registrationToken issued by POST /api/auth/google (P9-02: the
/// token binds the subsequent complete-registration call to this Google session).
class GoogleLoginRequiresRegistration extends GoogleLoginResult {
  final String userId;
  final String registrationToken;
  const GoogleLoginRequiresRegistration(this.userId, this.registrationToken);
}

/// P1-04: the Google email belongs to an existing password account that has
/// not completed email verification yet. Linking is blocked server-side so
/// the OTP gate can't be bypassed — finish verification via email instead.
class GoogleLoginRequiresVerification extends GoogleLoginResult {
  final String email;
  const GoogleLoginRequiresVerification(this.email);
}

// ─── Email / password outcomes (P1-03) ───────────────────────────────────────

/// Result of [AuthRepository.login] and [AuthRepository.register].
///
/// P1-03 moved both behind an email-verification gate: the backend only
/// issues a JWT once `EmailVerified == true`, so an unverified account comes
/// back as [AuthNeedsEmailVerification] and the client routes to the OTP screen.
sealed class AuthOutcome {
  const AuthOutcome();
}

/// JWT stored — navigate to the role landing page.
class AuthSignedIn extends AuthOutcome {
  const AuthSignedIn();
}

/// Account exists but `EmailVerified == false`. No token was stored.
class AuthNeedsEmailVerification extends AuthOutcome {
  final String email;
  const AuthNeedsEmailVerification(this.email);
}

// ─── Repository ───────────────────────────────────────────────────────────────

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  // google_sign_in 7.x singleton — initialized once in main.dart.
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  AuthRepository(this._dio, this._storage);

  // ── Email / password ────────────────────────────────────────────────────────

  /// Returns [AuthSignedIn] when the account is verified (JWT stored), or
  /// [AuthNeedsEmailVerification] when the backend replies 403 with
  /// `requiresVerification` — P1-03 gates login on `EmailVerified`.
  Future<AuthOutcome> login(String email, String password) async {
    try {
      final response = await _dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });
      await _storeTokens(response.data);
      return const AuthSignedIn();
    } on DioException catch (e) {
      debugPrint('[AuthRepository] login error: $e');
      final verificationEmail = _verificationRequiredEmail(e, fallback: email);
      if (verificationEmail != null) {
        return AuthNeedsEmailVerification(verificationEmail);
      }
      throw Exception(_friendlyDioError(e));
    } catch (e) {
      debugPrint('[AuthRepository] login unexpected error: $e');
      throw Exception('Something went wrong. Please try again.');
    }
  }

  /// P1-03: registration always leaves the account unverified — the backend
  /// mails a 6-digit code and returns no tokens, so the outcome is
  /// [AuthNeedsEmailVerification] unless the call itself fails.
  Future<AuthOutcome> register(String firstName, String lastName, String email,
      String password, int role) async {
    try {
      final response = await _dio.post('/api/auth/register', data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'role': role, // 0 = Homeowner, 1 = Tradie (backend UserRole enum)
      });
      return AuthNeedsEmailVerification(
        response.data['email'] as String? ?? email,
      );
    } on DioException catch (e) {
      debugPrint('[AuthRepository] register error: $e');
      throw Exception(_friendlyDioError(e));
    } catch (e) {
      debugPrint('[AuthRepository] register unexpected error: $e');
      throw Exception('Something went wrong. Please try again.');
    }
  }

  // ── Email OTP (P1-03) ───────────────────────────────────────────────────────

  /// Verifies the 6-digit code for [email] and stores the returned JWT.
  /// Throws a friendly [Exception] on invalid / expired / over-attempted codes.
  Future<void> verifyEmail(String email, String code) async {
    try {
      final response = await _dio.post('/api/auth/verify-email', data: {
        'email': email,
        'code': code,
      });
      await _storeTokens(response.data);
    } on DioException catch (e) {
      debugPrint('[AuthRepository] verifyEmail error: $e');
      throw Exception(_friendlyDioError(e));
    } catch (e) {
      debugPrint('[AuthRepository] verifyEmail unexpected error: $e');
      throw Exception('Something went wrong. Please try again.');
    }
  }

  /// Asks the backend for a fresh code. Throws a friendly [Exception] when
  /// the 60s cooldown or the hourly cap (HTTP 429) rejects the request.
  Future<void> resendOtp(String email) async {
    try {
      await _dio.post('/api/auth/resend-otp', data: {'email': email});
    } on DioException catch (e) {
      debugPrint('[AuthRepository] resendOtp error: $e');
      throw Exception(_friendlyDioError(e));
    } catch (e) {
      debugPrint('[AuthRepository] resendOtp unexpected error: $e');
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
          response.data['userId'] as String,
          response.data['registrationToken'] as String,
        );
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
      // P1-04: an unverified password account blocks Google linking (403).
      final verificationEmail = _verificationRequiredEmail(e);
      if (verificationEmail != null) {
        return GoogleLoginRequiresVerification(verificationEmail);
      }
      throw Exception(_friendlyDioError(e));
    } catch (e) {
      debugPrint('[AuthRepository] Google login unexpected error: $e');
      rethrow;
    }
  }

  /// Called from RoleSelectScreen after a new Google user picks their role.
  ///
  /// P9-02: [registrationToken] is the one-time token issued by
  /// POST /api/auth/google — the backend rejects the call without it.
  Future<void> completeRegistration(
      String userId, String registrationToken, int role) async {
    try {
      final response = await _dio.patch(
        '/api/auth/complete-registration',
        queryParameters: {
          'userId': userId,
          'registrationToken': registrationToken,
        },
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
    // P9-06: revoke the refresh token server-side before clearing local
    // storage so a stolen token cannot be used after explicit logout.
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken != null) {
        await _dio.delete(
          '/api/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
      }
    } catch (_) {
      // Non-fatal — proceed with local sign-out regardless of network state.
    }
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

  /// P1-03 / P1-04: the backend signals "unverified account" with
  /// `{ requiresVerification: true, email }` on a 403 from `/auth/login`
  /// and `/auth/google`. Returns the email to show on the OTP screen, or
  /// null when this is an ordinary error the caller should surface normally.
  String? _verificationRequiredEmail(DioException e, {String? fallback}) {
    if (e.response?.statusCode != 403) return null;
    final body = e.response?.data;
    if (body is! Map || body['requiresVerification'] != true) return null;
    return (body['email'] as String?) ?? fallback;
  }

  /// Translates a [DioException] into a short, user-friendly message.
  /// Full technical detail is always printed to the debug console first.
  /// Shared implementation lives in `network/api_error.dart`; the status
  /// overrides below keep auth-specific copy (wrong password, unverified
  /// account, duplicate email) intact.
  String _friendlyDioError(DioException e) => friendlyDioError(
        e,
        tag: 'AuthRepository',
        statusOverrides: const {
          401: 'Incorrect email or password.',
          403: 'This account needs to be verified first.',
          409: 'An account with this email already exists.',
          429: 'Too many attempts. Please wait before trying again.',
        },
      );
}
