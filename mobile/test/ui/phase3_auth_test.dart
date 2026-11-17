// Phase 3.4: v2 auth screen tests (migration plan §4.0 recipe).
//
// The v1 auth flow tests (test/auth_ui_test.dart) keep testing the v1
// screens; this file proves the v2 rebuilds satisfy the same contracts:
// keys preserved, dispatch identical, semantics identical, light + dark.
// v2 screens self-wrap in ThScope, so dark variants come from
// MediaQuery.platformBrightness (ThemeMode.system default).
import 'package:dio/dio.dart';
import 'package:fixo/repositories/auth_repository.dart';
import 'package:fixo/ui/auth/onboarding_screen.dart';
import 'package:fixo/ui/auth/role_select_screen.dart';
import 'package:fixo/ui/auth/sign_in_screen.dart';
import 'package:fixo/ui/auth/sign_up_screen.dart';
import 'package:fixo/ui/auth/splash_screen.dart';
import 'package:fixo/ui/auth/verify_otp_screen.dart';
import 'package:fixo/ui/design/th_widgets.dart';
import 'package:fixo/viewmodels/auth_viewmodel.dart';
import 'package:fixo/viewmodels/locale_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'phase3_test_setup.dart';

/// Same fake as test/auth_ui_test.dart's TestAuth: subclass of the real
/// notifier, real repository ctor, no network calls happen.
class _V2Auth extends AuthNotifier {
  _V2Auth() : super(AuthRepository(Dio(), const FlutterSecureStorage()));
  List<Object>? registration;
  int verifications = 0;
  int resends = 0;
  List<Object>? submitted;
  bool roleSuccess = false;

  @override
  Future<AuthOutcome?> login(String email, String password) async {
    submitted = [email, password];
    return AuthNeedsEmailVerification(email);
  }

  @override
  Future<AuthOutcome?> register(
    String first,
    String last,
    String email,
    String password,
    int role,
  ) async {
    submitted = [first, last, email, password, role];
    return AuthNeedsEmailVerification(email);
  }

  @override
  Future<GoogleLoginResult> loginWithGoogle() async =>
      const GoogleLoginRequiresRegistration('google-user', 'single-use');

  @override
  Future<bool> completeRegistration(
    String userId,
    String token,
    int role,
  ) async {
    registration = [userId, token, role];
    return roleSuccess;
  }

  @override
  Future<bool> verifyEmail(String email, String code) async {
    verifications++;
    state = const AuthState(error: 'Code expired. Request a new code.');
    return false;
  }

  @override
  Future<bool> resendOtp(String email) async {
    resends++;
    state = const AuthState();
    return true;
  }
}

void main() {
  setUpAll(() async {
    await loadPhase3Fixtures();
    FlutterSecureStorage.setMockInitialValues({});
  });

  // v2 screens self-wrap in ThScope; dark variants come from
  // MediaQuery.platformBrightness (ThemeMode.system default).
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen,
    _V2Auth auth, {
    bool dark = false,
    double scale = 1.0,
    bool reduceMotion = false,
    GoRouter? router,
    double width = 393,
    double height = 1400,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        authViewModelProvider.overrideWith((ref) => auth),
        localeConfigProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: router != null
            ? MaterialApp.router(
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: reduceMotion,
                    platformBrightness: dark
                        ? Brightness.dark
                        : Brightness.light,
                  ),
                  child: child!,
                ),
              )
            : MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: reduceMotion,
                    platformBrightness: dark
                        ? Brightness.dark
                        : Brightness.light,
                  ),
                  child: child!,
                ),
                home: screen,
              ),
      ),
    );
    await tester.pump();
  }

  GoRouter brouter(
    Map<String, Widget Function(GoRouterState)> routes,
    String initial,
  ) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        for (final entry in routes.entries)
          GoRoute(path: entry.key, builder: (_, state) => entry.value(state)),
      ],
    );
    return router;
  }

  for (final dark in [false, true]) {
    final t = dark ? 'dark' : 'light';

    for (final scale in [1.0, 2.0]) {
      testWidgets('v2 auth surfaces fit 320px at ${scale}x ($t)', (
        tester,
      ) async {
        for (final screen in [
          const ThSplashScreen(),
          const ThOnboardingScreen(),
          const ThSignInScreen(),
          const ThSignUpScreen(),
          const ThRoleSelectScreen(
            userId: 'user',
            registrationToken: 'one-time',
          ),
          const ThVerifyOtpScreen(email: 'long.address@example.co.nz'),
        ]) {
          // Fresh fake per screen: each mount owns a container that disposes
          // its notifier at teardown — sharing one instance across containers
          // would dispose it repeatedly.
          await pumpScreen(
            tester,
            screen,
            _V2Auth(),
            dark: dark,
            scale: scale,
            width: 320,
            height: 700,
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            tester.takeException(),
            isNull,
            reason: '$screen at 320px ${scale}x',
          );
        }
        // Flush the splash boot timer (2s) and ring staggers, then unmount so
        // the OTP countdown timer is cancelled before the test ends.
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }

    testWidgets(
      'v2 sign-in keeps the email/password/verify-email contract ($t)',
      (tester) async {
        final auth = _V2Auth();
        Object? routeExtra;
        final router = brouter({
          '/auth': (_) => const ThSignInScreen(),
          '/verify-email': (state) {
            routeExtra = state.extra;
            return const SizedBox();
          },
        }, '/auth');
        addTearDown(router.dispose);

        await pumpScreen(
          tester,
          const SizedBox(),
          auth,
          dark: dark,
          router: router,
        );
        await tester.enterText(
          find.byKey(const Key('email_field')),
          '  test@example.co.nz ',
        );
        await tester.enterText(
          find.byKey(const Key('password_field')),
          'StrongPass1!',
        );
        await tester.tap(find.byKey(const Key('login_button')));
        await tester.pump();

        expect(auth.submitted, ['test@example.co.nz', 'StrongPass1!']);
        expect(routeExtra, 'test@example.co.nz');
      },
    );

    testWidgets('v2 sign-up splits the name and routes to verification ($t)', (
      tester,
    ) async {
      final auth = _V2Auth();
      Object? routeExtra;
      final router = brouter({
        '/signup': (_) => const ThSignUpScreen(),
        '/verify-email': (state) {
          routeExtra = state.extra;
          return const SizedBox();
        },
      }, '/signup');
      addTearDown(router.dispose);

      await pumpScreen(
        tester,
        const SizedBox(),
        auth,
        dark: dark,
        router: router,
      );
      await tester.enterText(
        find.byKey(const Key('full_name_field')),
        'Test Person',
      );
      await tester.enterText(
        find.byKey(const Key('signup_email_field')),
        'new@example.co.nz',
      );
      await tester.enterText(
        find.byKey(const Key('signup_password_field')),
        'StrongPass1!',
      );
      await tester.tap(find.byKey(const Key('signup_button')));
      await tester.pump();

      expect(auth.submitted, [
        'Test',
        'Person',
        'new@example.co.nz',
        'StrongPass1!',
        0,
      ]);
      expect(routeExtra, 'new@example.co.nz');
    });
  }

  testWidgets('v2 splash stops decorative motion when reduce motion is on', (
    tester,
  ) async {
    final router = brouter({
      '/splash': (_) => const ThSplashScreen(),
      '/onboarding': (_) => const SizedBox(),
      '/auth': (_) => const SizedBox(),
    }, '/splash');
    addTearDown(router.dispose);
    await pumpScreen(
      tester,
      const SizedBox(),
      _V2Auth(),
      reduceMotion: true,
      router: router,
    );
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('v2 onboarding announces all three steps and advances', (
    tester,
  ) async {
    final auth = _V2Auth();
    await pumpScreen(tester, const ThOnboardingScreen(), auth, height: 852);

    for (var page = 1; page <= 3; page++) {
      expect(
        find.bySemanticsLabel('Step $page of 3'),
        findsWidgets,
        reason: 'page $page',
      );
      if (page < 3) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
    }
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('v2 signup password rules update as the user types', (
    tester,
  ) async {
    final auth = _V2Auth();
    await pumpScreen(tester, const ThSignUpScreen(), auth);
    await tester.enterText(
      find.byKey(const Key('signup_password_field')),
      'StrongPass1!',
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Met: At least 8 characters'), findsOneWidget);
    expect(find.bySemanticsLabel('Met: A lowercase letter'), findsOneWidget);
    expect(find.bySemanticsLabel('Met: A symbol'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Not met: At least 8 characters'),
      findsNothing,
    );
  });

  testWidgets('v2 signup sticky action stays above the keyboard at 2x', (
    tester,
  ) async {
    final auth = _V2Auth();
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        authViewModelProvider.overrideWith((ref) => auth),
        localeConfigProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2.0),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
          home: const ThSignUpScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getBottomLeft(find.byKey(const Key('signup_button'))).dy,
      lessThanOrEqualTo(420),
    );

    // Empty form → truthful validators.
    await tester.tap(find.byKey(const Key('signup_button')));
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Please enter your email'), findsOneWidget);
  });

  testWidgets('v2 role selection waits for Continue and preserves token', (
    tester,
  ) async {
    final auth = _V2Auth();
    await pumpScreen(
      tester,
      const ThRoleSelectScreen(userId: 'user', registrationToken: 'one-time'),
      auth,
    );

    final continueButton = tester.widget<THButton>(
      find.widgetWithText(THButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNull);

    expect(find.byKey(const Key('role_helper')), findsOneWidget);
    expect(find.textContaining('switch later'), findsNothing);

    await tester.tap(find.text('Tradie'));
    await tester.pump();
    expect(auth.registration, isNull);
    expect(find.byKey(const Key('role_helper')), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(auth.registration, ['user', 'one-time', 1]);
  });

  testWidgets('v2 role select routes each role to its destination', (
    tester,
  ) async {
    final auth = _V2Auth()..roleSuccess = true;
    final destinations = <String>[];
    final router = GoRouter(
      initialLocation: '/role-select',
      routes: [
        GoRoute(
          path: '/role-select',
          builder: (_, _) => const ThRoleSelectScreen(
            userId: 'user',
            registrationToken: 'one-time',
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) {
            destinations.add('/home');
            return const Text('Home destination');
          },
        ),
        GoRoute(
          path: '/tradie/onboarding',
          builder: (_, _) {
            destinations.add('/tradie/onboarding');
            return const Text('Tradie destination');
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpScreen(tester, const SizedBox(), auth, router: router);
    await tester.tap(find.text('Tradie'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(auth.registration, ['user', 'one-time', 1]);
    expect(find.text('Tradie destination'), findsOneWidget);
  });

  testWidgets('v2 OTP paste, deletion, expiry and resend preserve dispatch', (
    tester,
  ) async {
    final auth = _V2Auth();
    await pumpScreen(
      tester,
      const ThVerifyOtpScreen(email: 'test@example.co.nz'),
      auth,
      height: 852,
    );

    final field = find.descendant(
      of: find.byType(THOtpInput),
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(field).autofillHints,
      contains(AutofillHints.oneTimeCode),
    );
    await tester.enterText(field, '123456');
    await tester.pump();
    expect(auth.verifications, 1);

    // Moving the caret must not re-verify.
    tester.widget<TextField>(field).controller!.selection =
        const TextSelection.collapsed(offset: 3);
    await tester.pump();
    expect(auth.verifications, 1);
    expect(find.text('Code expired. Request a new code.'), findsOneWidget);

    await tester.enterText(field, '12345');
    await tester.pump();
    expect(find.text('1 digit to go'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    final resend = find.byKey(const Key('resend_button'));
    await tester.ensureVisible(resend);
    await tester.tap(resend);
    await tester.pump();
    expect(auth.resends, 1);
    expect(find.text('6 digits to go'), findsOneWidget);

    // Unmount so the restarted 60s countdown timer is cancelled.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('v2 OTP keeps a static resend label across ticks', (
    tester,
  ) async {
    final auth = _V2Auth();
    await pumpScreen(
      tester,
      const ThVerifyOtpScreen(email: 'audit@fixo.test'),
      auth,
      height: 852,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.bySemanticsLabel('Resend code, on cooldown'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('resend_button'))).height,
      greaterThanOrEqualTo(48),
    );

    // Unmount so the countdown timer is cancelled before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
