import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Shared translation of transport/HTTP failures into short, user-facing
/// copy so every screen reports the same thing for the same failure.
///
/// Originally private to `AuthRepository`; extracted when the tradie
/// onboarding wizard needed identical handling.
String friendlyDioError(
  DioException e, {
  String tag = 'Api',
  Map<int, String> statusOverrides = const {},
}) {
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
      debugPrint('[$tag] HTTP $status body: $body');
      return switch (status) {
        400 => extractServerMessage(body) ?? 'Invalid details. Please check your input.',
        401 => statusOverrides[401] ?? 'Please sign in again.',
        403 => extractServerMessage(body) ??
            statusOverrides[403] ??
            'You do not have access to this.',
        409 => extractServerMessage(body) ??
            statusOverrides[409] ??
            'That conflicts with something that already exists.',
        413 => extractServerMessage(body) ?? 'That file is too large.',
        422 => extractServerMessage(body) ?? 'Validation failed.',
        429 => extractServerMessage(body) ??
            statusOverrides[429] ??
            'Too many attempts. Please wait before trying again.',
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
String? extractServerMessage(dynamic body) {
  if (body == null) return null;

  // ── ASP.NET Identity errors: [{code, description}, ...] ──────────────────
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
    // ── FluentValidation errors: {errors: {field: [msg, ...]}} ─────────────
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

    // ── FluentValidation raw list: [{propertyName, errorMessage}, ...] ────
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

    // ── Simple {message} or {title} ───────────────────────────────────────
    final msg = body['message'] ?? body['title'];
    if (msg is String && msg.isNotEmpty) return msg;
  }

  return null;
}
