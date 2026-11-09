import 'package:dio/dio.dart';
import 'package:fixo/repositories/chat_reviews_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/models/payment.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/widgets/tradie_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('failed reviews are not reported as success or empty data', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          ),
        ),
      );
    final repo = ReviewsRepository(dio, const FlutterSecureStorage());
    await expectLater(
      repo.submitReview('42', 5, null, revieweeId: 'target'),
      throwsA(isA<ProfileApiException>()),
    );
    await expectLater(
      repo.getReviewsForUser('target'),
      throwsA(isA<ProfileApiException>()),
    );
  });

  test('missing public profile metrics remain unknown', () {
    final profile = UserProfile.fromJson({});
    expect(profile.averageRating, isNull);
    expect(profile.reviewCount, isNull);
    expect(profile.isVerified, isNull);
  });

  test('missing match evidence is not verification or zero reviews', () {
    final match = TradieMatch.fromJson({});
    expect(match.verified, isFalse);
    expect(match.rating, isNull);
    expect(match.reviewCount, isNull);
    expect(match.distance, isEmpty);
  });

  for (final dark in [false, true]) {
    for (final count in <int?>[null, 0, 3]) {
      testWidgets('match evidence dark=$dark reviews=$count at 320px/2x', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? FixoTheme.dark() : FixoTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TradieCard(
                    initials: '',
                    name: '',
                    trade: '',
                    distance: '',
                    rating: count == 3 ? 4.5 : 0,
                    reviewCount: count,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Verified'), findsNothing);
        expect(find.text('0.0 (0)'), findsNothing);
        expect(
          find.text(
            (count == null || count == 0)
                ? 'New to TradieHunter'
                : '4.5 (3 reviews)',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('bank instructions reject empty and configured sentinels', () {
    for (final number in ['', '00-0000-0000000-00', '<account>', 'CHANGE_ME']) {
      expect(
        BankDetails(
          accountName: 'Legal Partner Ltd',
          accountNumber: number,
        ).isAvailable,
        isFalse,
      );
    }
    expect(
      const BankDetails(
        accountName: '',
        accountNumber: '12-3456-7890123-00',
      ).isAvailable,
      isFalse,
    );
  });

  test('bank instructions preserve legitimate legal identity verbatim', () {
    const bank = BankDetails(
      accountName: 'Fixo Legal Partner Ltd',
      accountNumber: '12-3456-7890123-00',
    );
    expect(bank.isAvailable, isTrue);
    expect(bank.accountName, 'Fixo Legal Partner Ltd');
  });
}
