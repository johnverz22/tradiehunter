import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/gallery/screen_gallery.dart' show ScreenGalleryPage;
import '../ui/tradie/tr_earnings_screen.dart';
import '../ui/tradie/tr_jobs_screen.dart';
import '../ui/tradie/tr_onboarding_screen.dart';
import '../ui/homeowner/ho_matching_screen.dart';
import '../ui/homeowner/ho_payment_screen.dart';
import '../ui/auth/splash_screen.dart';
import '../ui/auth/onboarding_screen.dart';
import '../ui/auth/sign_in_screen.dart';
import '../ui/auth/sign_up_screen.dart';
import '../ui/auth/verify_otp_screen.dart';
import '../ui/auth/role_select_screen.dart';
import '../ui/homeowner/ho_choose_tradie_screen.dart';
import '../ui/homeowner/ho_home_screen.dart';
import '../ui/homeowner/ho_jobs_screen.dart';
import '../ui/homeowner/ho_post_job_screen.dart';
import '../ui/homeowner/ho_tradie_profile_screen.dart';
import '../ui/homeowner/ho_public_profile_screen.dart';
import '../ui/homeowner/ho_categories_screen.dart';
import '../ui/homeowner/ho_browse_tradies_screen.dart';
import '../ui/homeowner/ho_job_detail_router.dart';
import '../ui/homeowner/ho_quotes_screen.dart';
import '../ui/homeowner/ho_dispute_screen.dart';
import '../ui/shared/th_shell.dart';
import '../ui/shared/chat_screen.dart';
import '../ui/shared/messages_list_screen.dart';
import '../ui/shared/notifications_screen.dart';
import '../ui/shared/profile_screen.dart';
import '../ui/shared/settings_screen.dart';
import '../ui/feedback/th_state_view.dart';
import '../ui/tradie/tr_home_screen.dart';
import '../ui/tradie/tr_job_router.dart';
import '../ui/tradie/tr_lead_screen.dart';

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

/// Optional route payloads are treated as absent when deep links or stale
/// callers provide a different shape.
String? routeCategorySeed(Object? extra) => extra is String ? extra : null;

String? routeGstLabel(Object? extra) => extra is String ? extra : null;

({String userId, String registrationToken})? routeRoleSelectExtra(
  Object? extra,
) => extra is ({String userId, String registrationToken}) ? extra : null;

String? routeVerificationEmail(Object? extra) =>
    extra is String && extra.trim().isNotEmpty ? extra : null;

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  // E-job-not-found (v1.6.2 frames-states.html) — unknown deep links render
  // the designed error screen instead of a blank page.
  errorBuilder: (context, state) => Scaffold(
    body: ThStateView.preset(
      ThStatePreset.jobNotFound,
      onAction: () => appRouter.go('/home'),
    ),
  ),
  routes: [
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
          const ThSplashScreen(),
    ),
    // 02-onboarding
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const ThOnboardingScreen(),
    ),
    // 03-login
    GoRoute(
      path: '/auth',
      builder: (context, state) =>
          const ThSignInScreen(),
    ),
    // 04-signup
    GoRoute(
      path: '/signup',
      builder: (context, state) =>
          const ThSignUpScreen(),
    ),

    // Shown after a new Google user authenticates — they pick Homeowner/Tradie.
    // P9-02: extra carries both the stub userId and the one-time registration
    // token issued by POST /api/auth/google:
    //   context.go('/role-select',
    //       extra: (userId: id, registrationToken: token))
    GoRoute(
      path: '/role-select',
      builder: (context, state) {
        final extra = routeRoleSelectExtra(state.extra);
        if (extra == null) {
          return Scaffold(
            body: ThStateView.error(
              message:
                  'Your sign-in session has expired. Please sign in again.',
              onRetry: () => appRouter.go('/auth'),
            ),
          );
        }
        final (:userId, :registrationToken) = extra;
        return ThRoleSelectScreen(
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
        final email = routeVerificationEmail(state.extra);
        if (email == null) {
          return Scaffold(
            body: ThStateView.error(
              message: 'We could not verify this email session. Please sign in again.',
              onRetry: () => appRouter.go('/auth'),
            ),
          );
        }
        return ThVerifyOtpScreen(email: email);
      },
    ),

    // H08 categories — browse the live service catalog
    GoRoute(
      path: '/categories',
      builder: (context, state) => const HoCategoriesScreen(),
    ),
    // H19 find-a-tradie — live tradie search (extra = category seed)
    GoRoute(
      path: '/find-tradie',
      builder: (context, state) => HoBrowseTradiesScreen(initialCategory: routeCategorySeed(state.extra)),
    ),
    // H20 notifications — FCM-fed inbox
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const ThNotificationsScreen(),
    ),
    // 06-post-job
    GoRoute(
      path: '/jobs/new',
      builder: (context, state) =>
          const ThPostJobScreen(),
    ),
    // 07-matching — dual-mode waiting screen (v1.7 P12-08/P12-09):
    //   /jobs/:id/matching = quick-match radar (POST /match + SignalR)
    //   /jobs/:id/request  = request-sent state for a direct request
    //     (extra: gstLabel — the D8 label for the tradie's snapshot rate)
    GoRoute(
      path: '/jobs/:jobId/matching',
      builder: (context, state) =>
          ThMatchingScreen(jobId: state.pathParameters['jobId']!),
    ),
    GoRoute(
      path: '/jobs/:jobId/request',
      builder: (context, state) => ThMatchingScreen(
        jobId: state.pathParameters['jobId']!,
        mode: ThMatchingMode.requestSent,
        gstLabel: routeGstLabel(state.extra),
      ),
    ),
    // v1.7 P12-06: Choose-a-Tradie — lands here after posting a job
    // (extra: gstLabel is not needed; the list rows carry their own).
    GoRoute(
      path: '/jobs/:jobId/tradies',
      builder: (context, state) => ThChooseTradieScreen(jobId: state.pathParameters['jobId']!),
    ),
    // v1.7 P12-24: homeowner quote comparison for Project jobs.
    GoRoute(
      path: '/jobs/:jobId/quotes',
      builder: (context, state) => HoQuotesScreen(jobId: state.pathParameters['jobId']!),
    ),
    // 10-request-detail (tradie)
    GoRoute(
      path: '/tradie/requests/:requestId',
      builder: (context, state) {
        final requestId = state.pathParameters['requestId']!;
        final key = ValueKey('request_$requestId');
        return TradieLeadScreen(key: key, requestId: requestId);
      },
    ),
    // 11-chat
    GoRoute(
      path: '/chat/:jobId',
      builder: (context, state) => ThChatScreen(
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
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return HoPaymentScreen(key: ValueKey('payment_$jobId'), jobId: jobId);
      },
    ),
    GoRoute(
      path: '/jobs/:jobId/payment/status',
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return HoPaymentStatusScreen(
          key: ValueKey('payment_status_$jobId'),
          jobId: jobId,
        );
      },
    ),
    // P5-07: Homeowner job detail — confirm-completion, review prompt, stepper.
    //   context.push('/jobs/:jobId/detail')
    GoRoute(
      path: '/jobs/:jobId/detail',
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return ThJobDetailRouter(
          key: ValueKey('job_detail_$jobId'),
          jobId: jobId,
        );
      },
    ),
    // P7-03: Dispute screen
    GoRoute(
      path: '/jobs/:jobId/dispute',
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return HoDisputeScreen(key: ValueKey('dispute_$jobId'), jobId: jobId);
      },
    ),
    // P5-06: Tradie active job detail — check-in / check-out actions.
    //   context.push('/tradie/jobs/:jobId')
    GoRoute(
      path: '/tradie/jobs/:jobId',
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return TrJobRouter(key: ValueKey('tradie_job_$jobId'), jobId: jobId);
      },
    ),
    // P1-09 tradie onboarding wizard. Declared before `/tradie/:id` so the
    // static segment wins over the public-profile parameter, and kept at
    // root level so the tabbed shell's bottom nav doesn't squeeze the form.
    //   context.push('/tradie/onboarding')
    GoRoute(
      path: '/tradie/onboarding',
      builder: (context, state) => const TrOnboardingScreen(),
    ),
    // D-P5-1 tradie earnings. Declared before `/tradie/:id` so the static
    // segment wins over the public-profile parameter.
    //   context.push('/tradie/earnings')
    GoRoute(
      path: '/tradie/earnings',
      builder: (context, state) => const TrEarningsScreen(),
    ),
    // 12-profile (tradie public/self). v1.7 P12-07: an optional `jobId`
    // query parameter switches the screen into job context — the tradie's
    // rate for the job's service + a sticky "Request this tradie" CTA
    // (POST /api/jobs/:id/request). Without it the screen is unchanged.
    GoRoute(
      path: '/tradie/:id',
      builder: (context, state) {
        final profileId = state.pathParameters['id']!;
        final jobId = state.uri.queryParameters['jobId'];
        return ThTradieProfileRoute(profileId: profileId, jobId: jobId);
      },
    ),
    // 15-homeowner-profile (public)
    GoRoute(
      path: '/users/:id',
      builder: (context, state) {
        final profileId = state.pathParameters['id']!;
        return HoPublicProfileScreen(profileId: profileId);
      },
    ),

    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) =>
          ThShell(child: child),
      routes: [
        // 05-homeowner-home
        GoRoute(
          path: '/home',
          builder: (context, state) => const ThHomeScreen(),
        ),
        // 09-tradie-home
        GoRoute(
          path: '/tradie',
          builder: (context, state) => const TradieHomeScreen(),
        ),
        GoRoute(
          path: '/jobs',
          // Shared by both roles (ThJobsRoute does the role split).
          builder: (context, state) =>
              const ThJobsRoute(tradieFallback: TrJobsScreen()),
        ),
        GoRoute(
          path: '/messages',
          builder: (context, state) => const ThMessagesListScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const ThProfileScreen(),
        ),
        // 14-settings — inside shell so Profile tab stays active
        GoRoute(
          path: '/settings',
          builder: (context, state) => const ThSettingsScreen(),
        ),
      ],
    ),
  ],
);
