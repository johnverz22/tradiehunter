import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../feedback/fixo_notice.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final FlutterSecureStorage storage;
  final GoRouter router;
  bool _isRefreshing = false;

  // Requests that arrived while a refresh was in-flight are queued here.
  // Each entry holds the pending handler; on success they are completed with
  // the new token, on failure they are rejected so the caller gets the error.
  final _pendingQueue = <({RequestInterceptorHandler? reqHandler, ErrorInterceptorHandler? errHandler, RequestOptions options})>[];

  AuthInterceptor(this.dio, this.storage, this.router);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await storage.read(key: 'jwt_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final isRefreshEndpoint =
        err.requestOptions.path.contains('/auth/refresh');

    // P9-06: A 401 from the refresh endpoint means the token is invalid/
    // expired/revoked. Clear credentials and show a user-visible error.
    if (isRefreshEndpoint) {
      await _signOutAndRedirect(
        message: 'Session expired — please sign in again.',
      );
      return handler.reject(err); // propagate so queued requests get rejected
    }

    // Already retried — avoid an infinite loop.
    if (err.requestOptions.extra['auth_retried'] == true) {
      await _signOutAndRedirect();
      return handler.reject(err);
    }

    // While a refresh is already in-flight, queue the failing request.
    if (_isRefreshing) {
      _pendingQueue.add((
        reqHandler: null,
        errHandler: handler,
        options: err.requestOptions,
      ));
      return; // do NOT call handler.next/reject yet
    }

    _isRefreshing = true;
    try {
      final refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken == null) throw Exception('No refresh token stored.');

      final response = await Dio()
          .post(
            '${dio.options.baseUrl}/api/auth/refresh',
            data: {'refreshToken': refreshToken},
          )
          .timeout(const Duration(seconds: 10));

      final newToken = response.data['token'] as String?;
      final newRefreshToken = response.data['refreshToken'] as String?;

      if (newToken == null || newToken.isEmpty) {
        throw Exception('Invalid refresh response — no token received.');
      }

      await storage.write(key: 'jwt_token', value: newToken);
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await storage.write(key: 'refresh_token', value: newRefreshToken);
      }

      // Retry the original request.
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      err.requestOptions.extra['auth_retried'] = true;
      final retryResponse = await dio.fetch(err.requestOptions);

      // P9-06: Drain the queue — reject each pending request with the error,
      // not silently drop it, so callers get a proper error and can react.
      for (final pending in _pendingQueue) {
        pending.options.headers['Authorization'] = 'Bearer $newToken';
        pending.options.extra['auth_retried'] = true;
        dio
            .fetch(pending.options)
            .then((r) => pending.errHandler?.resolve(r))
            .catchError((e) => pending.errHandler?.reject(e is DioException
                ? e
                : DioException(requestOptions: pending.options)));
      }
      _pendingQueue.clear();

      return handler.resolve(retryResponse);
    } catch (e) {
      // Refresh failed — reject every queued request so callers don't hang.
      for (final pending in _pendingQueue) {
        final dioErr = e is DioException
            ? e
            : DioException(
                requestOptions: pending.options,
                error: e,
              );
        pending.errHandler?.reject(dioErr);
      }
      _pendingQueue.clear();

      await _signOutAndRedirect(
        message: 'Session expired — please sign in again.',
      );
      return handler.reject(err);
    } finally {
      _isRefreshing = false;
    }
  }

  /// Clears stored tokens and navigates to the login screen.
  /// Optionally shows a snackbar [message] via the root scaffold messenger.
  Future<void> _signOutAndRedirect({String? message}) async {
    await storage.delete(key: 'jwt_token');
    await storage.delete(key: 'refresh_token');
    if (message != null) {
      // Use a post-frame callback so we don't trigger notice display during a build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = router.routerDelegate.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          FixoNotice.error(context, message);
        }
      });
    }
    router.go('/auth');
  }
}
