import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../views/main_layout.dart';
import '../views/splash_screen.dart';
import '../views/onboarding/onboarding_view.dart';
import '../views/login_screen.dart';
import '../views/signup_screen.dart';
import '../views/profile_screen.dart';
import '../views/settings_screen.dart';
import '../views/auth/role_select_screen.dart';
import '../views/auth/otp_verification_screen.dart';
import '../views/homeowner/homeowner_dashboard_view.dart';
import '../views/homeowner/homeowner_job_detail_screen.dart';
import '../views/tradie/tradie_dashboard_view.dart';
import '../views/tradie/tradie_onboarding_wizard.dart';
import '../views/tradie/request_detail_screen.dart';
import '../views/tradie/tradie_job_detail_screen.dart';
import '../views/jobs/jobs_list_screen.dart';
import '../views/jobs/post_job_screen.dart';
import '../views/jobs/matching_screen.dart';
import '../views/jobs/match_result_screen.dart';
import '../views/chat/chat_screen.dart';
import '../views/chat/messages_list_screen.dart';
import '../views/profile/public_profile_screen.dart';
import '../views/payment/payment_screen.dart';
import '../views/payment/payment_status_screen.dart';
import '../views/jobs/dispute_screen.dart';
import '../feedback/notice_gallery.dart';

/// Route map for the 15 mobile mockups (docs/design/mockup/mobile/).
/// Tabbed screens live inside the [MainLayout] shell; flow screens
/// (post-job → matching → match-result, request detail, chat) are
/// root-level so they render without a bottom nav bar.
final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Debug-only notice gallery — stripped from release builds.
    if (kDebugMode)
      GoRoute(
        path: '/debug/notice-gallery',
        builder: (context, state) =>
            maybeNoticeGallery() ?? const SizedBox.shrink(),
      ),
    // 01-splash
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    // 02-onboarding
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    // 03-login
    GoRoute(
      path: '/auth',
      builder: (context, state) => const LoginScreen(),
    ),
    // 04-signup
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),

    // Shown after a new Google user authenticates — they pick Homeowner/Tradie.
    // P9-02: extra carries both the stub userId and the one-time registration
    // token issued by POST /api/auth/google:
    //   context.go('/role-select',
    //       extra: (userId: id, registrationToken: token))
    GoRoute(
      path: '/role-select',
      builder: (context, state) {
        final (:userId, :registrationToken) =
            state.extra as ({String userId, String registrationToken});
        return RoleSelectScreen(
          userId: userId,
          registrationToken: registrationToken,
        );
      },
    ),

    // P1-08: email OTP gate. Reached after signup (registration always
    // leaves the account unverified) and after a 403 from /api/auth/login:
    //   context.go('/verify-email', extra: email)
    GoRoute(
      path: '/verify-email',
      builder: (context, state) {
        final email = state.extra as String;
        return OtpVerificationScreen(email: email);
      },
    ),

    // 06-post-job
    GoRoute(
      path: '/jobs/new',
      builder: (context, state) => const PostJobScreen(),
    ),
    // 07-matching
    GoRoute(
      path: '/jobs/:jobId/matching',
      builder: (context, state) => MatchingScreen(
        jobId: state.pathParameters['jobId']!,
      ),
    ),
    // 08-match-result
    GoRoute(
      path: '/jobs/:jobId/match',
      builder: (context, state) => MatchResultScreen(
        jobId: state.pathParameters['jobId']!,
      ),
    ),
    // 10-request-detail (tradie)
    GoRoute(
      path: '/tradie/requests/:requestId',
      builder: (context, state) => RequestDetailScreen(
        key: ValueKey('request_${state.pathParameters['requestId']}'),
        requestId: state.pathParameters['requestId']!,
      ),
    ),
    // 11-chat
    GoRoute(
      path: '/chat/:jobId',
      builder: (context, state) => ChatScreen(
        key: ValueKey('chat_${state.pathParameters['jobId']}'),
        jobId: state.pathParameters['jobId']!,
      ),
    ),
    // P4-07 homeowner payment. Both are root-level flow screens: paying is a
    // task with its own bottom action bar, not a tab.
    //   context.push('/jobs/:jobId/payment')
    //   context.push('/jobs/:jobId/payment/status')
    GoRoute(
      path: '/jobs/:jobId/payment',
      builder: (context, state) => PaymentScreen(
        key: ValueKey('payment_${state.pathParameters['jobId']}'),
        jobId: state.pathParameters['jobId']!,
      ),
    ),
    GoRoute(
      path: '/jobs/:jobId/payment/status',
      builder: (context, state) => PaymentStatusScreen(
        key: ValueKey('payment_status_${state.pathParameters['jobId']}'),
        jobId: state.pathParameters['jobId']!,
      ),
    ),
    // P5-07: Homeowner job detail — confirm-completion, review prompt, stepper.
    //   context.push('/jobs/:jobId/detail')
    GoRoute(
      path: '/jobs/:jobId/detail',
      builder: (context, state) => HomeownerJobDetailScreen(
        key: ValueKey('job_detail_${state.pathParameters['jobId']}'),
        jobId: state.pathParameters['jobId']!,
      ),
    ),
    // P7-03: Dispute screen
    GoRoute(
      path: '/jobs/:jobId/dispute',
      builder: (context, state) => DisputeScreen(
        key: ValueKey('dispute_${state.pathParameters['jobId']}'),
        jobId: state.pathParameters['jobId']!,
      ),
    ),
    // P5-06: Tradie active job detail — check-in / check-out actions.
    //   context.push('/tradie/jobs/:jobId')
    GoRoute(
      path: '/tradie/jobs/:jobId',
      builder: (context, state) => TradieJobDetailScreen(
        key: ValueKey('tradie_job_${state.pathParameters['jobId']}'),
        jobId: state.pathParameters['jobId']!,
      ),
    ),
    // P1-09 tradie onboarding wizard. Declared before `/tradie/:id` so the
    // static segment wins over the public-profile parameter, and kept at
    // root level so the tabbed shell's bottom nav doesn't squeeze the form.
    //   context.push('/tradie/onboarding')
    GoRoute(
      path: '/tradie/onboarding',
      builder: (context, state) => const TradieOnboardingWizard(),
    ),
    // 12-profile (tradie public/self)
    GoRoute(
      path: '/tradie/:id',
      builder: (context, state) => PublicProfileScreen(
        profileId: state.pathParameters['id']!,
        isTradie: true,
      ),
    ),
    // 15-homeowner-profile (public)
    GoRoute(
      path: '/users/:id',
      builder: (context, state) => PublicProfileScreen(
        profileId: state.pathParameters['id']!,
        isTradie: false,
      ),
    ),

    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainLayout(child: child),
      routes: [
        // 05-homeowner-home
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeownerDashboardView(),
        ),
    // 09-tradie-home
    GoRoute(
      path: '/tradie',
      builder: (context, state) => const TradieDashboardView(),
    ),
        GoRoute(
          path: '/jobs',
          builder: (context, state) => const JobsListScreen(),
        ),
        GoRoute(
          path: '/messages',
          builder: (context, state) => const MessagesListScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        // 14-settings — inside shell so Profile tab stays active
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
