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
import '../views/homeowner/homeowner_dashboard_view.dart';
import '../views/tradie/tradie_dashboard_view.dart';
import '../views/tradie/request_detail_screen.dart';
import '../views/jobs/jobs_list_screen.dart';
import '../views/jobs/post_job_screen.dart';
import '../views/jobs/matching_screen.dart';
import '../views/jobs/match_result_screen.dart';
import '../views/chat/chat_screen.dart';
import '../views/chat/messages_list_screen.dart';
import '../views/profile/public_profile_screen.dart';

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
    // userId is passed via GoRouter's extra parameter:
    //   context.go('/role-select', extra: userId)
    GoRoute(
      path: '/role-select',
      builder: (context, state) {
        final userId = state.extra as String;
        return RoleSelectScreen(userId: userId);
      },
    ),

    // 14-settings
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
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
        requestId: state.pathParameters['requestId']!,
      ),
    ),
    // 11-chat
    GoRoute(
      path: '/chat/:jobId',
      builder: (context, state) => ChatScreen(
        jobId: state.pathParameters['jobId']!,
      ),
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
          builder: (context, state) => const HomeownerHomeScreen(),
        ),
        // 09-tradie-home
        GoRoute(
          path: '/tradie',
          builder: (context, state) => const TradieHomeScreen(),
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
      ],
    ),
  ],
);
