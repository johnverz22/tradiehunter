import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'theme/fixo_theme.dart';
import 'viewmodels/auth_viewmodel.dart'; // authRepositoryProvider
import 'views/settings_screen.dart'; // themeModeProvider

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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register the background handler before runApp so it's in place
  // even if the app was launched from a terminated state by a notification.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // google_sign_in 7.x requires exactly one initialize() call before any
  // authenticate() / signOut() calls. serverClientId must match the backend's
  // Authentication:Google:ClientId and the value in mobile/.env.json.
  await GoogleSignIn.instance.initialize(
    serverClientId: const String.fromEnvironment('GOOGLE_CLIENT_ID'),
  );

  // Request notification permission (required on iOS; Android 13+ also needs it).
  await _requestNotificationPermission();

  // Check if the app was launched by tapping a notification (terminated state).
  // We store it and route after the widget tree is ready.
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

  runApp(
    ProviderScope(
      child: FixoApp(initialMessage: initialMessage),
    ),
  );
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
class FixoApp extends ConsumerStatefulWidget {
  final RemoteMessage? initialMessage;

  const FixoApp({super.key, this.initialMessage});

  @override
  ConsumerState<FixoApp> createState() => _FixoAppState();
}

class _FixoAppState extends ConsumerState<FixoApp> {
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification?.title != null)
              Text(
                notification!.title!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (notification?.body != null)
              Text(notification!.body!),
          ],
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _routeFromMessage(message),
        ),
      ),
    );
  }

  // Map the notification's `type` data field to a named route.
  // Backend should include `"type": "chat" | "job_status" | "match"` in the data payload.
  void _routeFromMessage(RemoteMessage message) {
    final type = message.data['type'] as String?;
    switch (type) {
      case 'chat':
      case 'job_status':
        appRouter.go('/messages');
      case 'match':
        appRouter.go('/jobs');
      default:
        // Don't try to role-route here — we're in a callback context where
        // we can't await. Just go to /messages which works for both roles,
        // or let the shell's profile-based nav pick the right tab bar.
        appRouter.go('/messages');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Fixo',
      theme: FixoTheme.light(),
      darkTheme: FixoTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
