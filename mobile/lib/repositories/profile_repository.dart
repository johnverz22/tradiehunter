import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProfileRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ProfileRepository(this._dio, this._storage);

  Future<Map<String, dynamic>> getCurrentProfile() async {
    final token = await _storage.read(key: 'jwt_token');
    final response = await _dio.get(
      '/api/profile',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data;
  }

  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    final token = await _storage.read(key: 'jwt_token');
    await _dio.put(
      '/api/profile',
      data: profileData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }
}
