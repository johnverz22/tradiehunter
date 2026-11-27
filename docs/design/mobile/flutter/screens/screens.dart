// GENERATED. Barrel + route table for the design-v2 screens.
import 'package:flutter/widgets.dart';
import 'splash_screen.dart';
import 'onboarding_screen.dart';
import 'role_select_screen.dart';
import 'sign_in_screen.dart';
import 'verify_otp_screen.dart';
import 'ho_home_screen.dart';
import 'ho_post_quick_screen.dart';
import 'ho_post_project_screen.dart';
import 'ho_quotes_screen.dart';
import 'ho_quote_detail_screen.dart';
import 'ho_choose_tradie_screen.dart';
import 'ho_tradie_profile_screen.dart';
import 'ho_request_sent_screen.dart';
import 'ho_job_booked_screen.dart';
import 'ho_extra_cost_screen.dart';
import 'ho_review_completion_screen.dart';
import 'ho_payment_screen.dart';
import 'ho_payment_status_screen.dart';
import 'ho_review_screen.dart';
import 'ho_dispute_screen.dart';
import 'ho_jobs_screen.dart';
import 'chat_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'tr_home_screen.dart';
import 'tr_lead_screen.dart';
import 'tr_job_screen.dart';
import 'tr_extra_cost_screen.dart';
import 'tr_complete_screen.dart';
import 'tr_earnings_screen.dart';
import 'tr_onboarding_screen.dart';

const Map<String, String> thScreenRoutes = {
  'splash': '/',
  'onboarding': '/onboarding',
  'role_select': '/role-select',
  'sign_in': '/login',
  'verify_otp': '/verify-email',
  'ho_home': '/home',
  'ho_post_quick': '/jobs/new',
  'ho_post_project': '/jobs/new (project)',
  'ho_quotes': '/jobs/:id/quotes',
  'ho_quote_detail': '/jobs/:id/quotes (View quote sheet)',
  'ho_choose_tradie': '/jobs/:id/tradies',
  'ho_tradie_profile': '/tradie/:id?jobId=',
  'ho_request_sent': '/jobs/:id/request',
  'ho_job_booked': '/jobs/:id/detail',
  'ho_extra_cost': '/jobs/:id/detail (adjustment)',
  'ho_review_completion': '/jobs/:id/detail (awaiting confirmation)',
  'ho_payment': '/jobs/:id/payment',
  'ho_payment_status': '/jobs/:id/payment/status',
  'ho_review': '/jobs/:id/detail (completed)',
  'ho_dispute': '/jobs/:id/dispute',
  'ho_jobs': '/jobs',
  'chat': '/chat/:jobId',
  'notifications': '/notifications',
  'profile': '/profile',
  'tr_home': '/tradie',
  'tr_lead': '/tradie/requests/:requestId',
  'tr_job': '/tradie/jobs/:jobId',
  'tr_extra_cost': '/tradie/jobs/:jobId (adjustment)',
  'tr_complete': '/tradie/jobs/:jobId (check-out)',
  'tr_earnings': '/tradie (earnings)',
  'tr_onboarding': '/tradie/onboarding',
};

/// Preview gallery builders keyed by screen id (use in a debug-only route).
final Map<String, WidgetBuilder> thScreenBuilders = {
  'splash': (_) => const SplashScreen(),
  'onboarding': (_) => const OnboardingScreen(),
  'role_select': (_) => const RoleSelectScreen(),
  'sign_in': (_) => const SignInScreen(),
  'verify_otp': (_) => const VerifyOtpScreen(),
  'ho_home': (_) => const HoHomeScreen(),
  'ho_post_quick': (_) => const HoPostQuickScreen(),
  'ho_post_project': (_) => const HoPostProjectScreen(),
  'ho_quotes': (_) => const HoQuotesScreen(),
  'ho_quote_detail': (_) => const HoQuoteDetailScreen(),
  'ho_choose_tradie': (_) => const HoChooseTradieScreen(),
  'ho_tradie_profile': (_) => const HoTradieProfileScreen(),
  'ho_request_sent': (_) => const HoRequestSentScreen(),
  'ho_job_booked': (_) => const HoJobBookedScreen(),
  'ho_extra_cost': (_) => const HoExtraCostScreen(),
  'ho_review_completion': (_) => const HoReviewCompletionScreen(),
  'ho_payment': (_) => const HoPaymentScreen(),
  'ho_payment_status': (_) => const HoPaymentStatusScreen(),
  'ho_review': (_) => const HoReviewScreen(),
  'ho_dispute': (_) => const HoDisputeScreen(),
  'ho_jobs': (_) => const HoJobsScreen(),
  'chat': (_) => const ChatScreen(),
  'notifications': (_) => const NotificationsScreen(),
  'profile': (_) => const ProfileScreen(),
  'tr_home': (_) => const TrHomeScreen(),
  'tr_lead': (_) => const TrLeadScreen(),
  'tr_job': (_) => const TrJobScreen(),
  'tr_extra_cost': (_) => const TrExtraCostScreen(),
  'tr_complete': (_) => const TrCompleteScreen(),
  'tr_earnings': (_) => const TrEarningsScreen(),
  'tr_onboarding': (_) => const TrOnboardingScreen(),
};
