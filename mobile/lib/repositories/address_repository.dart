import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/address.dart';
import '../network/api_error.dart';
import 'profile_repository.dart';

class AddressRepository {
  static const _cachedAddressKey = 'last_selected_address';

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

  /// Persists [address] to local storage so it can be pre-filled on the next
  /// visit to the Post a Job screen.
  Future<void> cacheAddress(AddressCandidate address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedAddressKey, jsonEncode(address.toJson()));
  }

  /// Returns the last address the user confirmed, or `null` if nothing is
  /// cached or the stored value cannot be parsed.
  Future<AddressCandidate?> loadCachedAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedAddressKey);
      if (raw == null) return null;
      return AddressCandidate.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}
