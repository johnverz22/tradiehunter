import 'dart:convert';
import 'dart:io' show File, Platform;

import 'test_config.dart';

const String _kManifestDefine = String.fromEnvironment('E2E_MANIFEST');

/// Reads persona credentials and API-created job IDs from the Plan 08 manifest
/// JSON (`E2E_MANIFEST` via `--dart-define` or environment variable), falling
/// back to [test_config.dart] defaults when no manifest is supplied.
class ManifestData {
  ManifestData({
    required this.homeownerEmail,
    required this.homeownerPassword,
    required this.tradieEmail,
    required this.tradiePassword,
    required this.jobs,
  });

  final String homeownerEmail;
  final String homeownerPassword;
  final String tradieEmail;
  final String tradiePassword;
  final List<Map<String, dynamic>> jobs;

  int? latestJobId(String scenario) {
    for (final job in jobs.reversed) {
      if (job['scenario'] == scenario && job['id'] is int) {
        return job['id'] as int;
      }
    }
    return null;
  }

  static ManifestData load() {
    final path = _kManifestDefine.isNotEmpty
        ? _kManifestDefine
        : (Platform.environment['E2E_MANIFEST'] ?? '');
    if (path.isEmpty) {
      return ManifestData(
        homeownerEmail: kHomeownerEmail,
        homeownerPassword: kHomeownerPassword,
        tradieEmail: kTradieEmail,
        tradiePassword: kTradiePassword,
        jobs: const [],
      );
    }

    final raw = File(path).readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final personas = (json['personas'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    Map<String, dynamic>? firstRole(String role) {
      for (final p in personas) {
        if (p['role'] == role) return p;
      }
      return null;
    }

    final ho = firstRole('homeowner');
    final tr = firstRole('tradie');
    final jobs = (json['jobs'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return ManifestData(
      homeownerEmail: ho?['email'] as String? ?? kHomeownerEmail,
      homeownerPassword: ho?['password'] as String? ?? kHomeownerPassword,
      tradieEmail: tr?['email'] as String? ?? kTradieEmail,
      tradiePassword: tr?['password'] as String? ?? kTradiePassword,
      jobs: jobs,
    );
  }
}
