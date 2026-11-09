import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_viewmodel.dart';

/// `GET /api/config/locale` — locale + brand config from the backend.
/// Returns `{ locale: LocaleOptions, commissionPercent, brand: { appName, supportEmail, ... } }`.
/// No auth required. Falls back to `null` so callers can keep their own
/// defaults rather than hardcoding NZD / brand name.
final localeConfigProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final dio = ref.watch(dioProvider);
    final res = await dio.get('/api/config/locale');
    return (res.data as Map).cast<String, dynamic>();
  } on DioException {
    return null;
  } catch (_) {
    return null;
  }
});

/// Currency symbol from locale config, defaulting to `$`.
String currencySymbolOf(Map<String, dynamic>? locale) =>
    (locale?['currencySymbol'] as String?)?.trim().isNotEmpty == true
        ? locale!['currencySymbol'] as String
        : '\$';
