import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/address.dart';
import '../network/api_error.dart';
import 'profile_repository.dart';

class AddressRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AddressRepository(this._dio, this._storage);

  Future<AddressSearchResult> search(String query) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) throw const ProfileApiException('Please sign in again.');
    try {
      final response = await _dio.get(
        '/api/addresses/search',
        queryParameters: {'query': query},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return AddressSearchResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw ProfileApiException(
        error.response?.statusCode == 503
            ? 'Address search is temporarily unavailable. Please try again.'
            : friendlyDioError(error, tag: 'Address'),
      );
    } on FormatException {
      throw const ProfileApiException(
        'Could not read address results. Please try again.',
      );
    } on TypeError {
      throw const ProfileApiException(
        'Could not read address results. Please try again.',
      );
    }
  }
}
