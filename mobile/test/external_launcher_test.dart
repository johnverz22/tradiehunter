import 'package:flutter_test/flutter_test.dart';
import 'package:fixo/network/external_launcher.dart';

void main() {
  const launcher = ExternalLauncher();

  group('ExternalLauncher mapUri trip setup', () {
    test('Apple Maps builds driving directions URI with coordinates', () {
      final uri = launcher.mapUri(
        latitude: -36.8485,
        longitude: 174.7633,
        app: MapApp.appleMaps,
      );
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['daddr'], '-36.8485,174.7633');
      expect(uri.queryParameters['dirflg'], 'd');
    });

    test('Apple Maps builds driving directions URI with address fallback', () {
      final uri = launcher.mapUri(
        address: '8 Ponsonby Road, Auckland',
        app: MapApp.appleMaps,
      );
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['daddr'], contains('Ponsonby'));
      expect(uri.queryParameters['dirflg'], 'd');
    });

    test('Google Maps builds universal directions URI with coordinates', () {
      final uri = launcher.mapUri(
        latitude: -36.8485,
        longitude: 174.7633,
        app: MapApp.googleMaps,
      );
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '-36.8485,174.7633');
      expect(uri.queryParameters['travelmode'], 'driving');
    });

    test('Google Maps builds universal directions URI with address fallback', () {
      final uri = launcher.mapUri(
        address: '8 Ponsonby Road, Auckland',
        app: MapApp.googleMaps,
      );
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], contains('Ponsonby'));
      expect(uri.queryParameters['travelmode'], 'driving');
    });

    test('Returns null when neither coordinates nor address are present', () {
      expect(launcher.mapUri(app: MapApp.appleMaps), isNull);
      expect(launcher.mapUri(address: '', app: MapApp.googleMaps), isNull);
      expect(launcher.mapUri(address: '   ', app: MapApp.googleMaps), isNull);
    });

    test('Coordinates take precedence over address', () {
      final uri = launcher.mapUri(
        address: 'Ignored Address',
        latitude: -36.8485,
        longitude: 174.7633,
        app: MapApp.appleMaps,
      );
      expect(uri!.queryParameters['daddr'], '-36.8485,174.7633');
    });
  });
}
