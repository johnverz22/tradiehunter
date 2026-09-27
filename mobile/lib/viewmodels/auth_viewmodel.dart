import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';
import '../network/auth_interceptor.dart';
import '../router/app_router.dart';

// Re-export result types so screens only need one import.
export '../repositories/auth_repository.dart'
    show
        GoogleLoginResult,
        GoogleLoginSuccess,
        GoogleLoginCancelled,
        GoogleLoginRequiresRegistration;

// ─── Providers ────────────────────────────────────────────────────────────────

final dioProvider = Provider<Dio>((ref) {
  // API_BASE_URL is injected via --dart-define-from-file=.env.json.
  // Use http://localhost:5000 in .env.json for all platforms:
  //   iOS Simulator  → localhost resolves to the Mac host directly.
  //   Android Emul.  → localhost is auto-rewritten to 10.0.2.2 below.
  //   Physical device → set API_BASE_URL to your LAN IP (e.g. http://192.168.1.x:5000).
  const configuredUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );

  // Android emulator uses 10.0.2.2 as the loopback alias for the host machine.
  // Transparently rewrite so a single .env.json works for both simulators.
  final baseUrl = (!kIsWeb && Platform.isAndroid)
      ? configuredUrl
          .replaceFirst('localhost', '10.0.2.2')
          .replaceFirst('127.0.0.1', '10.0.2.2')
      : configuredUrl;

  debugPrint('[Dio] baseUrl: $baseUrl');

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));
  final storage = ref.watch(secureStorageProvider);
  dio.interceptors.add(AuthInterceptor(dio, storage, appRouter));
  return dio;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepository(dio, storage);
});

/// Shared ProfileRepository provider (also used by ProfileViewModel).
/// Declared here so SplashScreen and auth screens can read role without
/// importing profile_viewmodel — avoids circular imports.
final sharedProfileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  return ProfileRepository(dio, storage);
});

/// Fetches the current user's role from the API and returns the
/// destination route string: '/tradie' for role==1 (Tradie), '/home' otherwise.
/// UserRole enum: Homeowner=0, Tradie=1, Admin=2.
/// Call this after every successful login / registration / splash check.
Future<String> getRoleRoute(ProfileRepository profileRepo) async {
  try {
    final profile = await profileRepo.getCurrentProfile();
    final role = profile['role'];
    return role == 1 ? '/tradie' : '/home';
  } catch (e) {
    debugPrint('[getRoleRoute] Could not fetch profile, defaulting to /home: $e');
    return '/home';
  }
}

// ─── State ────────────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoading;
  final String? error;

  const AuthState({this.isLoading = false, this.error});

  AuthState copyWith({bool? isLoading, String? error}) => AuthState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState());

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.login(email, password);
      await _postLoginHook();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _stripException(e));
      return false;
    }
  }

  /// Returns a [GoogleLoginResult]:
  /// - [GoogleLoginSuccess]              → navigate to /home
  /// - [GoogleLoginRequiresRegistration] → navigate to /role-select?userId=...
  /// - [GoogleLoginCancelled]            → do nothing
  Future<GoogleLoginResult> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.loginWithGoogle();
      if (result is GoogleLoginSuccess) await _postLoginHook();
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _stripException(e));
      return const GoogleLoginCancelled();
    }
  }

  Future<bool> register(String firstName, String lastName, String email,
      String password, int role) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.register(firstName, lastName, email, password, role);
      await _postLoginHook();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _stripException(e));
      return false;
    }
  }

  /// Called from RoleSelectScreen. Sends role to backend, stores JWT.
  Future<bool> completeRegistration(String userId, int role) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.completeRegistration(userId, role);
      await _postLoginHook();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _stripException(e));
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);

  Future<void> logout() async {
    await _repository.logout();
  }

  Future<void> _postLoginHook() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _repository.registerDeviceToken(token);
    } catch (e) {
      debugPrint('[AuthNotifier] Post-login FCM registration failed: $e');
    }
  }

  /// Strips the "Exception: " prefix that Dart adds when calling toString()
  /// on an [Exception], so the UI shows just the human-readable message.
  String _stripException(Object e) {
    final raw = e.toString();
    const prefix = 'Exception: ';
    return raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
  }
}

final authViewModelProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
