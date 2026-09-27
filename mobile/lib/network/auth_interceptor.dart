import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final FlutterSecureStorage storage;
  final GoRouter router;
  bool _isRefreshing = false;
  final _queuedRequests = <Map<String, dynamic>>[];

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
    if (err.response?.statusCode == 401) {
      if (!_isRefreshing) {
        _isRefreshing = true;
        try {
          final refreshToken = await storage.read(key: 'refresh_token');
          if (refreshToken == null) throw Exception('No refresh token');

          final response = await Dio().post(
            '${dio.options.baseUrl}/api/auth/refresh',
            data: {'refreshToken': refreshToken},
          );

          final newToken = response.data['token'];
          final newRefreshToken = response.data['refreshToken'];

          await storage.write(key: 'jwt_token', value: newToken);
          await storage.write(key: 'refresh_token', value: newRefreshToken);

          // Retry the original request
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final retryResponse = await dio.fetch(err.requestOptions);
          
          _isRefreshing = false;
          for (final req in _queuedRequests) {
            req['options'].headers['Authorization'] = 'Bearer $newToken';
            dio.fetch(req['options']).then(req['handler'].resolve).catchError(req['handler'].reject);
          }
          _queuedRequests.clear();
          
          return handler.resolve(retryResponse);
        } catch (e) {
          _isRefreshing = false;
          _queuedRequests.clear();
          await storage.delete(key: 'jwt_token');
          await storage.delete(key: 'refresh_token');
          router.go('/auth');
          return handler.next(err);
        }
      } else {
        // Queue the request
        _queuedRequests.add({'options': err.requestOptions, 'handler': handler});
      }
    } else {
      return handler.next(err);
    }
  }
}
