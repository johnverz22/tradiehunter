import 'package:dio/dio.dart';
import 'package:fixo/repositories/auth_repository.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/auth_viewmodel.dart';
import 'package:fixo/viewmodels/locale_viewmodel.dart';
import 'package:fixo/views/auth/otp_verification_screen.dart';
import 'package:fixo/views/auth/role_select_screen.dart';
import 'package:fixo/views/login_screen.dart';
import 'package:fixo/views/onboarding/onboarding_view.dart';
import 'package:fixo/views/signup_screen.dart';
import 'package:fixo/views/widgets/otp_code_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:fixo/views/splash_screen.dart';

class TestAuth extends AuthNotifier {
  TestAuth() : super(AuthRepository(Dio(), const FlutterSecureStorage()));
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
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> mount(
    WidgetTester tester,
    Widget screen,
    TestAuth auth, {
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith((ref) => auth),
          localeConfigProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: dark ? FixoTheme.dark() : FixoTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pump();
  }

  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('auth surfaces fit 320px/$scale dark=$dark', (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final screen in <Widget>[
          const SplashScreen(),
          const LoginScreen(),
          const SignupScreen(),
          const RoleSelectScreen(userId: 'user', registrationToken: 'one-time'),
          const OtpVerificationScreen(email: 'long.address@example.co.nz'),
          const OnboardingScreen(),
        ]) {
          await mount(tester, screen, TestAuth(), dark: dark, scale: scale);
          expect(tester.takeException(), isNull, reason: '$screen');
          if (screen is OtpVerificationScreen) {
            await tester.enterText(find.byType(TextField), '123456');
            await tester.pump();
            expect(tester.takeException(), isNull);
            expect(
              find.text('Code expired. Request a new code.'),
              findsOneWidget,
            );
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        }
      });
    }
  }

  for (final dark in [false, true]) {
    testWidgets('auth routes retain email and Google token dark=$dark', (
      tester,
    ) async {
      final auth = TestAuth();
      Object? routeExtra;
      final router = GoRouter(
        initialLocation: '/auth',
        routes: [
          GoRoute(path: '/auth', builder: (_, _) => const LoginScreen()),
          GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
          GoRoute(
            path: '/verify-email',
            builder: (_, state) {
              routeExtra = state.extra;
              return const Scaffold(body: Text('Verification destination'));
            },
          ),
          GoRoute(
            path: '/role-select',
            builder: (_, state) {
              routeExtra = state.extra;
              return const Scaffold(body: Text('Role destination'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
          authViewModelProvider.overrideWith((ref) => auth),
          localeConfigProvider.overrideWith((ref) async => null),
        ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: dark ? FixoTheme.dark() : FixoTheme.light(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'test@example.co.nz',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'StrongPass1!',
      );
      await tester.ensureVisible(find.byKey(const Key('login_button')));
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();
      expect(auth.submitted, ['test@example.co.nz', 'StrongPass1!']);
      expect(routeExtra, 'test@example.co.nz');
      expect(find.text('Verification destination'), findsOneWidget);
      router.go('/signup');
      await tester.pumpAndSettle();
      for (final entry in {
        'full_name_field': 'Test Person',
        'signup_email_field': 'new@example.co.nz',
        'signup_password_field': 'StrongPass1!',
      }.entries) {
        final field = find.byKey(Key(entry.key));
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      await tester.tap(find.byKey(const Key('signup_button')));
      await tester.pumpAndSettle();
      expect(auth.submitted, [
        'Test',
        'Person',
        'new@example.co.nz',
        'StrongPass1!',
        0,
      ]);
      expect(routeExtra, 'new@example.co.nz');
      for (final path in ['/auth', '/signup']) {
        router.go(path);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Continue with Google'));
        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();
        expect(routeExtra, (
          userId: 'google-user',
          registrationToken: 'single-use',
        ));
        expect(find.text('Role destination'), findsOneWidget);
      }
    });
  }

  testWidgets('onboarding keeps local pages and announces all three steps', (
    tester,
  ) async {
    await mount(tester, const OnboardingScreen(), TestAuth());
    for (var page = 1; page <= 3; page++) {
      expect(find.bySemanticsLabel('Step $page of 3'), findsWidgets);
      if (page < 3) {
        await tester.tap(find.text('Next'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
      }
    }
    expect(find.text('Get started'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('signup sticky action stays above keyboard at 320px and 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await mount(tester, const SignupScreen(), TestAuth(), scale: 2);
    expect(
      tester.getBottomLeft(find.byKey(const Key('signup_button'))).dy,
      lessThanOrEqualTo(420),
    );
    await tester.tap(find.byKey(const Key('signup_button')));
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'role selection waits for Continue and preserves one-time token',
    (tester) async {
      final auth = TestAuth();
      await mount(
        tester,
        const RoleSelectScreen(userId: 'user', registrationToken: 'one-time'),
        auth,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Tradie'));
      await tester.pump();
      expect(auth.registration, isNull);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(auth.registration, ['user', 'one-time', 1]);
    },
  );

  for (final role in [0, 1]) {
    testWidgets('role $role continues to its established destination', (
      tester,
    ) async {
      final auth = TestAuth()..roleSuccess = true;
      final router = GoRouter(
        initialLocation: '/role-select',
        routes: [
          GoRoute(
            path: '/role-select',
            builder: (_, _) => const RoleSelectScreen(
              userId: 'user',
              registrationToken: 'one-time',
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('Home destination')),
          ),
          GoRoute(
            path: '/tradie/onboarding',
            builder: (_, _) => const Scaffold(body: Text('Tradie destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
          authViewModelProvider.overrideWith((ref) => auth),
          localeConfigProvider.overrideWith((ref) async => null),
        ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: FixoTheme.light(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final choice = find.text(role == 0 ? 'Homeowner' : 'Tradie');
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
      expect(auth.registration, isNull);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(auth.registration, ['user', 'one-time', role]);
      expect(
        find.text(role == 0 ? 'Home destination' : 'Tradie destination'),
        findsOneWidget,
      );
    });
  }

  testWidgets('role select explains the disabled Continue, no false promise', (
    tester,
  ) async {
    await mount(
      tester,
      const RoleSelectScreen(userId: 'user', registrationToken: 'one-time'),
      TestAuth(),
    );
    expect(find.byKey(const Key('role_helper')), findsOneWidget);
    expect(find.textContaining('switch later'), findsNothing);
    await tester.tap(find.text('Homeowner'));
    await tester.pump();
    expect(find.byKey(const Key('role_helper')), findsNothing);
  });

  testWidgets('OTP offers a change-email path under the address', (
    tester,
  ) async {
    await mount(
      tester,
      const OtpVerificationScreen(email: 'test@example.co.nz'),
      TestAuth(),
    );
    expect(find.byKey(const Key('change_email_button')), findsOneWidget);
    expect(find.text('Use a different email'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('password rules update as the user types', (tester) async {
    await mount(tester, const SignupScreen(), TestAuth());
    final field = find.byKey(const Key('signup_password_field'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'StrongPass1!');
    await tester.pump();
    expect(find.bySemanticsLabel('Met: At least 8 characters'), findsOneWidget);
    expect(find.bySemanticsLabel('Met: A lowercase letter'), findsOneWidget);
    expect(find.bySemanticsLabel('Met: A symbol'), findsOneWidget);
  });

  testWidgets('OTP paste, deletion, expiry and resend preserve dispatch', (
    tester,
  ) async {
    final auth = TestAuth();
    await mount(
      tester,
      const OtpVerificationScreen(email: 'test@example.co.nz'),
      auth,
    );
    final field = find.descendant(
      of: find.byType(OtpCodeField),
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(field).autofillHints,
      contains(AutofillHints.oneTimeCode),
    );
    await tester.enterText(field, '123456');
    await tester.pump();
    expect(auth.verifications, 1);
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
    await tester.pumpWidget(const SizedBox());
  });
}
