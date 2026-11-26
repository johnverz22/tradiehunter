// Plan 08 P3 — Persona Fabric mobile verification.
//
// Driver decision (P3.1): uses Flutter `integration_test` rather than Maestro
// YAML because `mobile/lib/` currently only carries 2 `THTestId` hooks while
// the existing 14 suites and `auth_helper.dart` / `fixture_helper.dart` drive
// the app via `Key`s and `appRouter`.
//
//   flutter test integration_test/persona_fabric_test.dart \
//     --device-id <id> --dart-define=E2E_MANIFEST=../test-logs/.../manifest.json

import 'package:fixo/main.dart' as app;
import 'package:fixo/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/auth_helper.dart';
import 'helpers/manifest_helper.dart';
import 'helpers/test_config.dart';

const _persona = String.fromEnvironment('FIXO_PERSONA', defaultValue: 'both');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final manifest = ManifestData.load();

  if (_persona == 'homeowner' || _persona == 'both') {
    group('P3 — Homeowner manifest flow', () {
      testWidgets('homeowner logs in and views API-created job', (
        tester,
      ) async {
        app.main();
        await loginAs(
          tester,
          manifest.homeownerEmail,
          manifest.homeownerPassword,
        );

        expect(find.byKey(const Key('homeowner_dashboard')), findsOneWidget);

        final jobId = manifest.latestJobId('happy-path');
        if (jobId != null) {
          appRouter.go('/jobs/$jobId');
          await pumpFor(tester, kNetworkSettle);
          expect(find.textContaining('Journey'), findsWidgets);
        }
      });
    });
  }

  if (_persona == 'tradie' || _persona == 'both') {
    group('P3 — Tradie manifest flow', () {
      testWidgets('tradie logs in and views API-created job', (tester) async {
        await const FlutterSecureStorage().deleteAll();
        app.main();
        await loginAs(
          tester,
          manifest.tradieEmail,
          manifest.tradiePassword,
        );

        expect(find.byKey(const Key('tradie_dashboard')), findsOneWidget);

        final jobId = manifest.latestJobId('happy-path');
        if (jobId != null) {
          appRouter.go('/tradie/jobs/$jobId');
          await pumpFor(tester, kNetworkSettle);
          expect(find.textContaining('Journey'), findsWidgets);
        }
      });
    });
  }
}
