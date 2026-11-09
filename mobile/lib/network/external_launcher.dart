import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Supported external navigation applications.
enum MapApp {
  appleMaps,
  googleMaps,
}

extension MapAppX on MapApp {
  String get displayName {
    switch (this) {
      case MapApp.appleMaps:
        return 'Apple Maps';
      case MapApp.googleMaps:
        return 'Google Maps';
    }
  }
}

/// Thin wrapper around `url_launcher` so screens never call the plugin
/// directly — tests override [externalLauncherProvider] with a fake.
///
/// Every method returns whether the external app was handed the intent;
/// callers must surface a truthful failure (e.g. "no maps app") rather than
/// assume success.
class ExternalLauncher {
  const ExternalLauncher();

  /// Opens the platform maps app or specified [app] with turn-by-turn driving
  /// directions / trip already set up to the destination.
  /// Coordinates take precedence; falls back to an address query.
  /// Returns false when there is nothing to navigate to or no handler accepts the intent.
  Future<bool> openMap({
    String? address,
    double? latitude,
    double? longitude,
    MapApp? app,
  }) async {
    // If Google Maps is explicitly requested on iOS, attempt native app scheme first
    if (app == MapApp.googleMaps &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      final dest = _destinationQuery(
        address: address,
        latitude: latitude,
        longitude: longitude,
      );
      if (dest != null) {
        final nativeUri = Uri.parse(
          'comgooglemaps://?daddr=$dest&directionsmode=driving',
        );
        if (await canLaunchUrl(nativeUri)) {
          final ok = await launchUrl(
            nativeUri,
            mode: LaunchMode.externalApplication,
          );
          if (ok) return true;
        }
      }
    }

    final uri = mapUri(
      address: address,
      latitude: latitude,
      longitude: longitude,
      app: app,
    );
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens the phone dialler with [phoneNumber]. Returns false for empty
  /// numbers or when no dialler accepts the intent.
  Future<bool> callPhone(String phoneNumber) async {
    final digits = phoneNumber.trim();
    if (digits.isEmpty) return false;
    return launchUrl(
      Uri(scheme: 'tel', path: digits),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Formats the destination parameter for turn-by-turn navigation.
  static String? _destinationQuery({
    String? address,
    double? latitude,
    double? longitude,
  }) {
    if (latitude != null && longitude != null) {
      return '$latitude,$longitude';
    }
    final trimmed = address?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return Uri.encodeComponent(trimmed);
  }

  /// Builds the maps URI with trip directions configured.
  /// Visible for testing to verify proper URI construction.
  @visibleForTesting
  Uri? mapUri({
    String? address,
    double? latitude,
    double? longitude,
    MapApp? app,
  }) {
    final dest = _destinationQuery(
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
    if (dest == null) return null;

    final targetApp = app ??
        (defaultTargetPlatform == TargetPlatform.iOS
            ? MapApp.appleMaps
            : MapApp.googleMaps);

    switch (targetApp) {
      case MapApp.appleMaps:
        // 'daddr' sets destination; 'dirflg=d' requests driving directions route
        return Uri.parse('https://maps.apple.com/?daddr=$dest&dirflg=d');
      case MapApp.googleMaps:
        // Official Google Maps universal directions URL with driving mode preset
        return Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving',
        );
    }
  }
}

final externalLauncherProvider = Provider<ExternalLauncher>(
  (ref) => const ExternalLauncher(),
);
