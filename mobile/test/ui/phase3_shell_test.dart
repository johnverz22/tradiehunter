// Phase 3.4: ThShell + chatUnreadProvider tests (migration plan 3.1).
//
// Proves the v2 shell mirrors v1 MainLayout behaviour: role-aware tabs,
// prefix-based active tab, role-dependent landing route, homeowner-only
// new-request action, dock badge fed by the unread aggregation, rail at
// ≥1024px, light + dark.
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/chat_reviews_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/ui/design/th_widgets.dart';
import 'package:fixo/ui/shared/chat_unread_provider.dart';
import 'package:fixo/ui/shared/th_shell.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart'
    show chatRepositoryProvider;
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'phase3_test_setup.dart';

class _ProfileRepo extends ProfileRepository {
  final Map<String, dynamic> profileMap;
  _ProfileRepo(this.profileMap) : super(Dio(), const FlutterSecureStorage());
  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => profileMap;
}

class _ChatRepo extends ChatRepository {
  List<ConversationSummary> conversations;
  bool conversationsThrow = false;
  int refreshCalls = 0;

  _ChatRepo(this.conversations) : super(Dio(), const FlutterSecureStorage());

  @override
  Future<List<ConversationSummary>> getConversations() async {
    refreshCalls++;
    if (conversationsThrow) {
      throw const ProfileApiException('offline');
    }
    return conversations;
  }
}

ConversationSummary _conv(String jobId, int unread) => ConversationSummary(
  jobId: jobId,
  jobTitle: 'Job $jobId',
  status: 'Booked',
  otherUserId: 'other',
  unreadCount: unread,
);

void main() {
  setUpAll(() async {
    await loadPhase3Fixtures();
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> pumpShell(
    WidgetTester tester,
    _ProfileRepo profile, {
    required _ChatRepo chat,
    bool dark = false,
    double width = 390,
    String initial = '/home',
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String label(String path) => switch (path) {
      '/home' => 'HOME SCREEN',
      '/tradie' => 'TRADIE SCREEN',
      '/jobs' => 'JOBS SCREEN',
      '/messages' => 'MESSAGES SCREEN',
      '/profile' => 'PROFILE SCREEN',
      '/settings' => 'SETTINGS SCREEN',
      _ => path,
    };

    final router = GoRouter(
      initialLocation: initial,
      routes: [
        ShellRoute(
          builder: (context, state, child) => ThShell(child: child),
          routes: [
            for (final path in [
              '/home',
              '/tradie',
              '/jobs',
              '/messages',
              '/profile',
              '/settings',
            ])
              GoRoute(path: path, builder: (_, _) => Text(label(path))),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(profile),
        chatRepositoryProvider.overrideWithValue(chat),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              platformBrightness: dark ? Brightness.dark : Brightness.light,
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('homeowner shell shows the dock and the new-request FAB', (
    tester,
  ) async {
    await pumpShell(
      tester,
      _ProfileRepo(const {'role': 0}),
      chat: _ChatRepo(const []),
    );
    expect(find.byType(THDock), findsOneWidget);
    expect(find.byKey(const Key('post_job_fab')), findsOneWidget);
    expect(find.text('Post job'), findsNothing);
    expect(find.text('HOME SCREEN'), findsOneWidget);

    // Full-bleed bar flush with the bottom edge; routed content ends where it
    // begins (nothing renders behind or around it).
    final dock = tester.getRect(find.byType(THDock));
    expect(dock.left, 0);
    expect(dock.right, 390);
    expect(dock.bottom, 1400);
    expect(
      tester.getRect(find.text('HOME SCREEN')).bottom,
      lessThanOrEqualTo(dock.top),
    );

    // Tap the Chat tab → /messages inside the same shell.
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.text('MESSAGES SCREEN'), findsOneWidget);
  });

  testWidgets('tradie shell has no FAB and lands tab 0 on /tradie', (
    tester,
  ) async {
    await pumpShell(
      tester,
      _ProfileRepo(const {'role': 1}),
      chat: _ChatRepo(const []),
      initial: '/tradie',
    );
    expect(find.byKey(const Key('post_job_fab')), findsNothing);
    expect(find.text('TRADIE SCREEN'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('TRADIE SCREEN'), findsOneWidget);
  });

  testWidgets('the chat badge aggregates unread counts and refreshes', (
    tester,
  ) async {
    final chat = _ChatRepo([_conv('1', 2), _conv('2', 1)]);
    await pumpShell(
      tester,
      _ProfileRepo(const {'role': 0}),
      chat: chat,
      initial: '/messages',
    );
    expect(find.text('3'), findsOneWidget);

    // The badge source refreshes on shell navigation.
    chat.conversations = [];
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsNothing);
  });

  testWidgets('counts above 99 render as 99+', (tester) async {
    await pumpShell(
      tester,
      _ProfileRepo(const {'role': 0}),
      chat: _ChatRepo([_conv('1', 142)]),
      initial: '/messages',
    );
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('active tab follows the location', (tester) async {
    await pumpShell(
      tester,
      _ProfileRepo(const {'role': 0}),
      chat: _ChatRepo(const []),
      initial: '/jobs',
    );
    expect(tester.widget<THDock>(find.byType(THDock)).active, THDockTab.jobs);
  });

  testWidgets('profile tab stays active on /settings (v1 behaviour)', (
    tester,
  ) async {
    await pumpShell(
      tester,
      _ProfileRepo(const {'role': 0}),
      chat: _ChatRepo(const []),
      initial: '/settings',
    );
    expect(
      tester.widget<THDock>(find.byType(THDock)).active,
      THDockTab.profile,
    );
  });

  testWidgets('rail replaces the dock at 1024px and keeps the FAB', (
    tester,
  ) async {
    await pumpShell(
      tester,
      _ProfileRepo(const {'role': 0}),
      chat: _ChatRepo(const []),
      width: 1200,
    );
    expect(find.byType(THDock), findsNothing);
    expect(find.byKey(const Key('post_job_fab')), findsNothing);
    // Rail renders the same four destinations + its own new-request action.
    expect(find.text('Home'), findsOneWidget);
    expect(find.byTooltip('New request'), findsOneWidget);
    expect(find.text('Post job'), findsOneWidget);
  });

  testWidgets('shell renders in light and dark without exceptions', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await pumpShell(
        tester,
        _ProfileRepo(const {'role': 0}),
        chat: _ChatRepo(const []),
        dark: dark,
      );
      expect(tester.takeException(), isNull, reason: dark ? 'dark' : 'light');
    }
  });

  group('chatUnreadProvider', () {
    test('sums unreadCount across conversations', () async {
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(
            _ChatRepo([_conv('1', 2), _conv('2', 0), _conv('3', 5)]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(chatUnreadProvider.notifier).refresh();
      expect(container.read(chatUnreadProvider), const AsyncValue.data(7));
    });

    test('errors surface instead of pretending zero', () async {
      final chat = _ChatRepo(const [])..conversationsThrow = true;
      final container = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(chat)],
      );
      addTearDown(container.dispose);
      await container.read(chatUnreadProvider.notifier).refresh();
      expect(container.read(chatUnreadProvider).hasError, isTrue);
    });
  });
}
