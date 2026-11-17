import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/gallery/screen_gallery.dart' show ScreenGalleryPage;
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
import '../views/jobs/tradie_list_screen.dart';
import '../views/jobs/quotes_screen.dart';
import '../views/chat/chat_screen.dart';
import '../views/chat/messages_list_screen.dart';
import '../views/profile/public_profile_screen.dart';
import '../views/payment/payment_screen.dart';
import '../views/payment/payment_status_screen.dart';
import '../views/jobs/dispute_screen.dart';
import '../views/homeowner/categories_screen.dart';
import '../views/homeowner/browse_tradies_screen.dart';
import '../views/notifications/notifications_screen.dart';
import '../views/states/designed_empty_state.dart';
import '../widgets/fixo_buttons.dart';
import '../feedback/notice_gallery.dart';
import '../ui/ui_flags.dart';
import '../ui/auth/splash_screen.dart';
import '../ui/auth/onboarding_screen.dart';
import '../ui/auth/sign_in_screen.dart';
import '../ui/auth/sign_up_screen.dart';
import '../ui/auth/verify_otp_screen.dart';
import '../ui/auth/role_select_screen.dart';
import '../ui/homeowner/ho_home_screen.dart';
import '../ui/shared/th_shell.dart';
import '../ui/shared/chat_screen.dart';
import '../ui/shared/messages_list_screen.dart';
import '../ui/shared/notifications_screen.dart';
import '../ui/shared/profile_screen.dart';
import '../ui/shared/settings_screen.dart';

/// Route map for the 15 mobile mockups (docs/design/mockup/mobile/).
/// Tabbed screens live inside the [MainLayout] shell; flow screens
/// (post-job → matching → match-result, request detail, chat) are
/// root-level so they render without a bottom nav bar.
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

/// Per-screen v1↔v2 switch (migration plan §4.0): the route builds the v2
/// screen only when its id is in [v2Screens] (or --dart-define=UI_V2=all);
/// otherwise it builds the old screen. Rollback of any screen is a one-line
/// flag change.
Widget _pick(String id, Widget v1, Widget v2) => isV2Screen(id) ? v2 : v1;

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  // E-job-not-found (v1.6.2 frames-states.html) — unknown deep links render
  // the designed error screen instead of a blank page.
  errorBuilder: (context, state) => Scaffold(
    appBar: FixoAppBar(title: 'Job not found'),
    body: DesignedEmptyState(
      variant: DesignedStateVariant.jobNotFound,
      onAction: () => appRouter.go('/home'),
    ),
  ),
  routes: [
    // Debug-only notice gallery — stripped from release builds.
    if (kDebugMode)
      GoRoute(
        path: '/debug/notice-gallery',
        builder: (context, state) =>
            maybeNoticeGallery() ?? const SizedBox.shrink(),
      ),
    // v2 design gallery (migration plan 2.6) — debug only.
    if (kDebugMode)
      GoRoute(
        path: '/debug/screen-gallery',
        builder: (context, state) => ScreenGalleryPage(
          initialScreen: state.uri.queryParameters['screen'],
          initialDark: state.uri.queryParameters['theme'] == 'dark',
        ),
      ),
    // 01-splash
    GoRoute(
      path: '/',
      builder: (context, state) =>
          _pick('splash', const SplashScreen(), const ThSplashScreen()),
    ),
    // 02-onboarding
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => _pick(
        'onboarding',
        const OnboardingScreen(),
        const ThOnboardingScreen(),
      ),
    ),
    // 03-login
    GoRoute(
      path: '/auth',
      builder: (context, state) =>
          _pick('sign_in', const LoginScreen(), const ThSignInScreen()),
    ),
    // 04-signup
    GoRoute(
      path: '/signup',
      builder: (context, state) =>
          _pick('signup', const SignupScreen(), const ThSignUpScreen()),
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
        return _pick(
          'role_select',
          RoleSelectScreen(
            userId: userId,
            registrationToken: registrationToken,
          ),
          ThRoleSelectScreen(
            userId: userId,
            registrationToken: registrationToken,
          ),
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
        return _pick(
          'verify_otp',
          OtpVerificationScreen(email: email),
          ThVerifyOtpScreen(email: email),
        );
      },
    ),

    // H08 categories — browse the live service catalog
    GoRoute(
      path: '/categories',
      builder: (context, state) => const CategoriesScreen(),
    ),
    // H19 find-a-tradie — live tradie search (extra = category seed)
    GoRoute(
      path: '/find-tradie',
      builder: (context, state) =>
          BrowseTradiesScreen(initialCategory: state.extra as String?),
    ),
    // H20 notifications — FCM-fed inbox
    GoRoute(
      path: '/notifications',
      builder: (context, state) => _pick(
        'notifications',
        const NotificationsScreen(),
        const ThNotificationsScreen(),
      ),
    ),
    // 06-post-job
    GoRoute(
      path: '/jobs/new',
      builder: (context, state) => const PostJobScreen(),
    ),
    // 07-matching — dual-mode waiting screen (v1.7 P12-08/P12-09):
    //   /jobs/:id/matching = quick-match radar (POST /match + SignalR)
    //   /jobs/:id/request  = request-sent state for a direct request
    //     (extra: gstLabel — the D8 label for the tradie's snapshot rate)
    GoRoute(
      path: '/jobs/:jobId/matching',
      builder: (context, state) =>
          MatchingScreen(jobId: state.pathParameters['jobId']!),
    ),
    GoRoute(
      path: '/jobs/:jobId/request',
      builder: (context, state) => MatchingScreen(
        jobId: state.pathParameters['jobId']!,
        mode: MatchingScreenMode.requestSent,
        gstLabel: state.extra is String ? state.extra as String? : null,
      ),
    ),
    // v1.7 P12-06: Choose-a-Tradie — lands here after posting a job
    // (extra: gstLabel is not needed; the list rows carry their own).
    GoRoute(
      path: '/jobs/:jobId/tradies',
      builder: (context, state) =>
          TradieListScreen(jobId: state.pathParameters['jobId']!),
    ),
    // v1.7 P12-24: homeowner quote comparison for Project jobs.
    GoRoute(
      path: '/jobs/:jobId/quotes',
      builder: (context, state) =>
          QuotesScreen(jobId: state.pathParameters['jobId']!),
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
      builder: (context, state) => _pick(
        'chat',
        ChatScreen(
          key: ValueKey('chat_${state.pathParameters['jobId']}'),
          jobId: state.pathParameters['jobId']!,
        ),
        ThChatScreen(
          key: ValueKey('chat_${state.pathParameters['jobId']}'),
          jobId: state.pathParameters['jobId']!,
        ),
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
    // 12-profile (tradie public/self). v1.7 P12-07: an optional `jobId`
    // query parameter switches the screen into job context — the tradie's
    // rate for the job's service + a sticky "Request this tradie" CTA
    // (POST /api/jobs/:id/request). Without it the screen is unchanged.
    GoRoute(
      path: '/tradie/:id',
      builder: (context, state) => PublicProfileScreen(
        profileId: state.pathParameters['id']!,
        isTradie: true,
        jobId: state.uri.queryParameters['jobId'],
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
      builder: (context, state, child) =>
          _pick('shell', MainLayout(child: child), ThShell(child: child)),
      routes: [
        // 05-homeowner-home
        GoRoute(
          path: '/home',
          builder: (context, state) => _pick(
            'ho_home',
            const HomeownerDashboardView(),
            const ThHomeScreen(),
          ),
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
          builder: (context, state) => _pick(
            'messages_list',
            const MessagesListScreen(),
            const ThMessagesListScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              _pick('profile', const ProfileScreen(), const ThProfileScreen()),
        ),
        // 14-settings — inside shell so Profile tab stays active
        GoRoute(
          path: '/settings',
          builder: (context, state) => _pick(
            'settings',
            const SettingsScreen(),
            const ThSettingsScreen(),
          ),
        ),
      ],
    ),
  ],
);
