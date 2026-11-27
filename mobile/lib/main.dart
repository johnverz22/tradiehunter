import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'ui/feedback/th_notice.dart';
import 'router/app_router.dart';
import 'router/notification_route.dart';
import 'ui/design/th_tokens.dart' show THTheme;
import 'viewmodels/auth_viewmodel.dart'; // authRepositoryProvider
import 'ui/shared/notification_center.dart'; // notificationCenterProvider (H20)
import 'viewmodels/jobs_viewmodel.dart'; // jobsViewModelProvider, quotesProvider
import 'viewmodels/locale_viewmodel.dart'; // localeConfigProvider
import 'viewmodels/theme_mode_viewmodel.dart'; // themeModeProvider

// ─── FCM background handler ─────────────────────────────────────────────────
// Must be a top-level function — it runs in a separate Dart isolate when the
// app is backgrounded or terminated. Keep it lightweight.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be re-initialised in the background isolate.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FCM background message: ${message.messageId}');
  // The OS notification tray handles display.
  // Any local-state updates (badge counts, etc.) can be done here.
}

// ─── Entry point ────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    // Integration tests re-invoke main() per test — the app is already there.
    if (e.code != 'duplicate-app') rethrow;
  }

  // Register the background handler before runApp so it's in place
  // even if the app was launched from a terminated state by a notification.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // google_sign_in 7.x requires exactly one initialize() call before any
  // authenticate() / signOut() calls. serverClientId must match the backend's
  // Authentication:Google:ClientId and the value in mobile/.env.json.
  try {
    await GoogleSignIn.instance
        .initialize(
          serverClientId: const String.fromEnvironment('GOOGLE_CLIENT_ID'),
        )
        .timeout(const Duration(seconds: 5));
  } catch (_) {
    // Already initialized (main() re-run by tests/hot restart) or the plugin
    // hung — either way, don't hold runApp hostage for it.
  }

  // Request notification permission (required on iOS; Android 13+ also needs it).
  // Fire-and-forget: awaiting would hold runApp behind the system prompt —
  // nobody answers it in integration tests, so the app would never start.
  // FIXO_DISABLE_PUSH skips it entirely (screenshot/test runs) — the
  // unanswered prompt still photobombs simctl captures.
  if (!const bool.fromEnvironment('FIXO_DISABLE_PUSH')) {
    unawaited(_requestNotificationPermission());
  }

  // Check if the app was launched by tapping a notification (terminated state).
  // We store it and route after the widget tree is ready.
  final initialMessage = await FirebaseMessaging.instance
      .getInitialMessage()
      .timeout(const Duration(seconds: 3), onTimeout: () => null);

  runApp(ProviderScope(child: ThApp(initialMessage: initialMessage)));
}

// ─── Permission request ──────────────────────────────────────────────────────
Future<void> _requestNotificationPermission() async {
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  debugPrint('FCM permission: ${settings.authorizationStatus}');
}

// ─── Root widget ─────────────────────────────────────────────────────────────
class ThApp extends ConsumerStatefulWidget {
  final RemoteMessage? initialMessage;

  const ThApp({super.key, this.initialMessage});

  @override
  ConsumerState<ThApp> createState() => _ThAppState();
}

class _ThAppState extends ConsumerState<ThApp> {
  @override
  void initState() {
    super.initState();
    _wireFcmListeners();

    // Route from the launch notification once the first frame is rendered.
    if (widget.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _routeFromMessage(widget.initialMessage!);
      });
    }
  }

  void _wireFcmListeners() {
    // Token refresh — FCM rotates the token after reinstalls, data clears, etc.
    // Always sync the new token to the backend.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM token refreshed');
      final repo = ref.read(authRepositoryProvider);
      await repo.registerDeviceToken(newToken);
    });

    // Foreground messages — the app is open and active.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground: ${message.notification?.title}');
      _handleForegroundMessage(message);
    });

    // User tapped a notification while the app was backgrounded (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM tapped (backgrounded): ${message.data}');
      _routeFromMessage(message);
    });
  }

  // Show an in-app banner for foreground messages and offer a navigation action.
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (!mounted) return;

    // Record the live message in the H20 notifications inbox (H20 mockup).
    ref
        .read(notificationCenterProvider.notifier)
        .add(
          ThNotification.fromRemote(
            title: notification?.title,
            body: notification?.body,
            data: message.data,
          ),
        );

    // Plan 10 Q2.7: a new quote refreshes the jobs list badge and quotes screen.
    if (message.data['type'] == 'quote_submitted') {
      ref.read(jobsViewModelProvider.notifier).loadHomeownerJobs();
      final jobId = message.data['jobId']?.toString();
      if (jobId != null && jobId.isNotEmpty) {
        ref.invalidate(quotesProvider(jobId));
      }
    }

    THNotice.push(
      context,
      title: notification?.title ?? 'Fixo',
      body: notification?.body ?? '',
      onView: () => _routeFromMessage(message),
    );
  }

  // Map the notification's `type` data field to a named route.
  // Backend should include `"type": "chat" | "job_status" | "match"` in the data payload.
  void _routeFromMessage(RemoteMessage message) {
    // The shell route itself resolves homeowner/tradie destinations by role.
    appRouter.go(routeForMessage(message.data));
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    // P10-24: read app name from brand config; fallback to 'TradieHunter'.
    // The /api/config/locale response nests brand under the 'brand' key.
    final localeData = ref.watch(localeConfigProvider).value;
    final appName =
        (localeData?['brand'] as Map<String, dynamic>?)?['appName']
            as String? ??
        'TradieHunter';

    return MaterialApp.router(
      title: appName,
      theme: THTheme.light,
      darkTheme: THTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      // Theme-aware status-bar icons for every screen (light theme → dark
      // icons). `context` here sits below MaterialApp's resolved Theme.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: THTheme.systemOverlayStyle(Theme.of(context).brightness),
        child: THNoticeHost(child: child ?? const SizedBox()),
      ),
    );
  }
}
