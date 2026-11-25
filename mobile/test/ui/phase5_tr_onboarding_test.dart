import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixo/models/tradie_onboarding.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/ui/tradie/tr_onboarding_mapper.dart';
import 'package:fixo/ui/tradie/tr_onboarding_screen.dart';
import 'package:fixo/viewmodels/tradie_onboarding_viewmodel.dart';

class _FakeOnboardingNotifier extends TradieOnboardingNotifier {
  _FakeOnboardingNotifier(TradieOnboardingState initial)
      : super(_DummyRepo()) {
    state = initial;
  }

  @override
  Future<void> load() async {}

  @override
  Future<bool> saveStepAndAdvance() async {
    state = state.copyWith(step: state.step + 1);
    return true;
  }

  @override
  Future<bool> finishSetup() async => true;
}

class _DummyRepo implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('renders step 0 work details and advances on Continue', (
    tester,
  ) async {
    final notifier = _FakeOnboardingNotifier(
      TradieOnboardingState(
        step: 0,
        firstName: 'Sam',
        lastName: 'Lee',
        phone: '021123456',
        address: '10 Queen St',
        latitude: '-36.8485',
        longitude: '174.7633',
        serviceRadiusKm: Decimal.fromInt(25),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tradieOnboardingProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: TrOnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up your profile'), findsOneWidget);
    expect(find.text('Step 1 of 4 · Where you work'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 4 · Trades'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('step 2 shows credentials and upload button', (tester) async {
    final notifier = _FakeOnboardingNotifier(
      TradieOnboardingState(
        step: 2,
        credentials: [
          TradieCredential(
            id: 1,
            type: 'License',
            originalFileName: 'plumbers_licence.pdf',
            status: 'Verified',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tradieOnboardingProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: TrOnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 4 · Credentials'), findsOneWidget);
    expect(find.text('plumbers_licence.pdf'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.byKey(const Key('upload_document_button')), findsOneWidget);
  });

  test('mapper helpers format labels', () {
    expect(trOnboardingCtaLabel(0, isSaving: false), 'Continue');
    expect(trOnboardingCtaLabel(3, isSaving: false), 'Finish setup');
    expect(trCredentialStatusLabel('approved'), 'Verified');
    expect(trCredentialStatusLabel('rejected'), 'Rejected');
    expect(trCredentialStatusLabel('pending'), 'Pending');
  });
}
