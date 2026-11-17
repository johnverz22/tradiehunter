// Phase 3.4: v2 shared screen tests — chat, messages inbox, notifications,
// profile, settings (migration plan §4.0 recipe).
//
// Same contract style as the v1 suites (test/chat_screens_test.dart,
// test/profiles_settings_test.dart): fakes subclass the real repositories,
// keys/semantics/copy are asserted verbatim, light + dark where it matters.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/network/external_launcher.dart';
import 'package:fixo/repositories/auth_repository.dart';
import 'package:fixo/repositories/chat_reviews_repository.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/ui/shared/chat_screen.dart';
import 'package:fixo/ui/shared/messages_list_screen.dart';
import 'package:fixo/ui/shared/notifications_screen.dart';
import 'package:fixo/ui/shared/profile_screen.dart';
import 'package:fixo/ui/shared/settings_screen.dart';
import 'package:fixo/viewmodels/auth_viewmodel.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/locale_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/widgets/notification_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'phase3_test_setup.dart';

// ── Fixtures (same shape as the v1 suites) ────────────────────────────────────

ChatMessage _msg(
  String id, {
  String senderId = 'other',
  String senderName = 'Rangi',
  bool sentByMe = false,
  String text = 'hello',
  DateTime? sentAt,
}) => ChatMessage(
  id: id,
  jobId: '7',
  senderId: senderId,
  senderName: senderName,
  sentByMe: sentByMe,
  text: text,
  sentAtUtc: sentAt ?? DateTime.utc(2026, 11, 3, 9),
);

class _ChatRepo extends ChatRepository {
  List<ConversationSummary> conversations = const [];
  bool conversationsThrow = false;
  List<ChatMessage> history = const [];
  bool historyThrow = false;
  bool hubSendThrows = false;
  bool restSendThrows = false;
  int markReadAfterReload = 0;

  int joinCalls = 0;
  int historyCalls = 0;
  final hubSends = <String>[];
  final restSends = <String>[];
  final reads = <int>[];

  _ChatRepo() : super(Dio(), const FlutterSecureStorage());

  @override
  Stream<ChatMessage> get onNewMessage => const Stream.empty();
  @override
  Stream<void> get onReconnected => const Stream.empty();

  @override
  Future<List<ConversationSummary>> getConversations() async {
    if (conversationsThrow) {
      throw const ProfileApiException('offline');
    }
    return conversations;
  }

  @override
  Future<ChatHistoryResult> getMessages(
    String jobId, {
    int? beforeId,
    int pageSize = 30,
  }) async {
    historyCalls++;
    if (historyThrow) throw const ProfileApiException('offline');
    return ChatHistoryResult(
      messages: history,
      hasMore: false,
      oldestId: history.isEmpty ? null : int.tryParse(history.last.id),
    );
  }

  @override
  Future<void> connectHub(String baseUrl) async {}

  @override
  Future<void> joinJob(String jobId) async {
    joinCalls++;
  }

  @override
  Future<void> leaveJob(String jobId) async {}

  @override
  Future<void> markRead(String jobId, int messageId) async {
    reads.add(messageId);
  }

  @override
  Future<void> sendMessageViaHub(String jobId, String text) async {
    if (hubSendThrows) throw StateError('send failed');
    hubSends.add(text);
  }

  @override
  Future<ChatMessage> sendMessageViaRest(String jobId, String text) async {
    if (restSendThrows) throw const ProfileApiException('send failed');
    restSends.add(text);
    return _msg('900', senderId: 'me', sentByMe: true, text: text);
  }
}

class _JobsRepo extends JobsRepository {
  Job? job;
  JobContact? contact;

  _JobsRepo({this.job, this.contact})
    : super(Dio(), const FlutterSecureStorage());

  @override
  Future<Job?> getJobById(String jobId) async => job;

  @override
  Future<JobContact?> getJobContact(String jobId) async => contact;

  @override
  Future<List<Job>> getMyJobs({String? status}) async =>
      job == null ? const [] : [job!];
}

class _ProfileRepo extends ProfileRepository {
  final Map<String, dynamic> profileMap;
  bool? availabilitySaved;
  Map<String, dynamic>? updatePayload;

  _ProfileRepo(this.profileMap) : super(Dio(), const FlutterSecureStorage());
  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => profileMap;
  @override
  Future<void> updateAvailability(bool isAvailable) async {
    availabilitySaved = isAvailable;
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    updatePayload = profileData;
  }
}

class _Launcher extends ExternalLauncher {
  final calls = <String>[];
  @override
  Future<bool> callPhone(String phoneNumber) async {
    calls.add(phoneNumber);
    return true;
  }
}

class _FakeAuth extends AuthNotifier {
  _FakeAuth() : super(AuthRepository(Dio(), const FlutterSecureStorage()));
  @override
  Future<void> logout() async {}
}

Job _job(String status) => Job(
  id: '7',
  title: 'Fix leaking tap',
  category: 'Plumbing',
  suburb: 'Auckland',
  status: status,
  stage: 0,
  homeownerId: 'ho-1',
  matchedTradieId: 'tr-1',
);

ConversationSummary _conv({
  String jobId = '7',
  String name = 'Rangi',
  String jobTitle = 'Fix leaking tap',
  String? preview = 'See you Tuesday',
  bool mine = false,
  int unread = 3,
}) => ConversationSummary(
  jobId: jobId,
  jobTitle: jobTitle,
  status: 'Booked',
  otherUserId: 'other',
  otherFirstName: name,
  lastMessage: preview,
  lastMessageMine: mine,
  unreadCount: unread,
);

void main() {
  setUp(() {
    // Fresh mock prefs per test: NotificationCenter persists to
    // SharedPreferences, so seeded notifications must not leak across tests.
    SharedPreferences.setMockInitialValues({});
  });

  setUpAll(() async {
    await loadPhase3Fixtures();
    FlutterSecureStorage.setMockInitialValues({});
  });

  // ── Chat screen ─────────────────────────────────────────────────────────────

  Future<void> mountChat(
    WidgetTester tester,
    _ChatRepo chat,
    _JobsRepo jobs, {
    _Launcher? launcher,
    _ProfileRepo? profile,
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(chat),
        jobsRepositoryProvider.overrideWithValue(jobs),
        externalLauncherProvider.overrideWithValue(launcher ?? _Launcher()),
        profileRepositoryProvider.overrideWithValue(
          profile ?? _ProfileRepo(const {'role': 0}),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              platformBrightness: dark ? Brightness.dark : Brightness.light,
            ),
            child: child!,
          ),
          home: const ThChatScreen(jobId: '7'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('v2 chat: participant-first header, job as subtitle', (
    tester,
  ) async {
    await mountChat(
      tester,
      _ChatRepo()..history = [_msg('1', senderName: 'Rangi', text: 'Kia ora')],
      _JobsRepo(
        job: _job('Booked'),
        contact: const JobContact(userId: 'other', firstName: 'Mere'),
      ),
    );
    // Contact name leads the header; the job is the subtitle.
    expect(find.text('Mere'), findsOneWidget);
    expect(find.text('Fix leaking tap'), findsOneWidget);
    expect(find.text('Kia ora'), findsOneWidget);
    // The incoming bubble still shows the sender name above it.
    expect(find.text('Rangi'), findsOneWidget);
    // Status pill carries the v1 step copy.
    expect(find.text('Step 2 of 4 · Booked'), findsOneWidget);
  });

  testWidgets('v2 chat: send goes through the existing hub path', (
    tester,
  ) async {
    final chat = _ChatRepo()..history = [_msg('1')];
    await mountChat(tester, chat, _JobsRepo(job: _job('Booked')));
    await tester.enterText(find.byType(TextField), 'see you then');
    await tester.tap(find.byKey(const Key('send_message_button')));
    await tester.pump();
    expect(chat.hubSends, ['see you then']);
  });

  testWidgets('v2 chat: quick replies populate without sending', (
    tester,
  ) async {
    final chat = _ChatRepo()..history = [_msg('1')];
    await mountChat(tester, chat, _JobsRepo(job: _job('Booked')));
    expect(find.bySemanticsLabel('That works for me.'), findsOneWidget);
    await tester.tap(find.text('That works for me.'));
    await tester.pump();
    expect(chat.hubSends, isEmpty);
    expect(chat.restSends, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller;
    expect(controller!.text, 'That works for me.');
  });

  testWidgets('v2 chat: failed send shows retry; tapping it redelivers', (
    tester,
  ) async {
    final chat = _ChatRepo()
      ..history = [_msg('1')]
      ..hubSendThrows = true
      ..restSendThrows = true;
    await mountChat(tester, chat, _JobsRepo(job: _job('Booked')));
    await tester.enterText(find.byType(TextField), 'will call you');
    await tester.tap(find.byKey(const Key('send_message_button')));
    await tester.pump();
    expect(find.text('Not sent — tap to retry'), findsOneWidget);

    chat.hubSendThrows = false;
    chat.restSendThrows = false;
    await tester.tap(find.text('Not sent — tap to retry'));
    await tester.pump();
    expect(chat.hubSends, ['will call you']);
  });

  testWidgets('v2 chat: disputed jobs lock the composer like the server', (
    tester,
  ) async {
    await mountChat(
      tester,
      _ChatRepo()..history = [_msg('1')],
      _JobsRepo(job: _job('Disputed')),
    );
    expect(find.text('Messaging is disabled for this job.'), findsOneWidget);
    expect(find.text('Chat is closed — job disputed.'), findsOneWidget);
    expect(find.byKey(const Key('send_message_button')), findsNothing);
    expect(find.text('Disputed'), findsOneWidget);
  });

  testWidgets('v2 chat: history failure shows a retryable error', (
    tester,
  ) async {
    final chat = _ChatRepo()..historyThrow = true;
    await mountChat(tester, chat, _JobsRepo(job: _job('Booked')));
    expect(find.text('Could not load messages.'), findsOneWidget);
    chat.historyThrow = false;
    chat.history = [_msg('1')];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Kia ora'), findsNothing);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('v2 chat: call is shown only when the server authorized', (
    tester,
  ) async {
    final launcher = _Launcher();
    await mountChat(
      tester,
      _ChatRepo()..history = [_msg('1')],
      _JobsRepo(
        job: _job('Booked'),
        contact: const JobContact(
          userId: 'other',
          firstName: 'Mere',
          phoneNumber: '+64 21 555 010',
        ),
      ),
      launcher: launcher,
    );
    expect(find.bySemanticsLabel('Call'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Call'));
    await tester.pump();
    expect(launcher.calls, ['+64 21 555 010']);

    // No phone number → no call affordance. Unmount first: pumpWidget with
    // the same widget type would UPDATE the existing state (keeping the
    // fetched contact) instead of building a fresh screen.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await mountChat(
      tester,
      _ChatRepo()..history = [_msg('1')],
      _JobsRepo(job: _job('Booked')),
    );
    expect(find.bySemanticsLabel('Call'), findsNothing);
  });

  testWidgets('v2 chat renders in light and dark without exceptions', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await mountChat(
        tester,
        _ChatRepo()..history = [_msg('1')],
        _JobsRepo(job: _job('Booked')),
        dark: dark,
      );
      expect(tester.takeException(), isNull, reason: dark ? 'dark' : 'light');
    }
  });

  // ── Messages inbox ──────────────────────────────────────────────────────────

  Future<void> mountInbox(
    WidgetTester tester,
    _ChatRepo chat, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ThMessagesListScreen()),
        GoRoute(
          path: '/chat/:id',
          builder: (_, state) => Scaffold(
            key: const Key('thread'),
            body: Text('Thread ${state.uri.path}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(chat)],
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

  testWidgets('v2 inbox: name, job, real preview and unread badge', (
    tester,
  ) async {
    await mountInbox(tester, _ChatRepo()..conversations = [_conv()]);
    expect(find.text('Rangi'), findsOneWidget);
    expect(find.text('Fix leaking tap'), findsOneWidget);
    expect(find.text('See you Tuesday'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('v2 inbox: own-message preview is prefixed truthfully', (
    tester,
  ) async {
    await mountInbox(
      tester,
      _ChatRepo()..conversations = [_conv(mine: true, unread: 0)],
    );
    expect(find.text('You: See you Tuesday'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('v2 inbox: empty thread shows no fake preview', (tester) async {
    await mountInbox(
      tester,
      _ChatRepo()..conversations = [_conv(preview: null, unread: 0)],
    );
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('v2 inbox: load failure shows a retryable error state', (
    tester,
  ) async {
    final chat = _ChatRepo()..conversationsThrow = true;
    await mountInbox(tester, chat);
    expect(find.text('Could not load conversations.'), findsOneWidget);
    chat.conversationsThrow = false;
    chat.conversations = [_conv()];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Rangi'), findsOneWidget);
  });

  testWidgets('v2 inbox: empty inbox is truthful', (tester) async {
    await mountInbox(tester, _ChatRepo()..conversations = const []);
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('v2 inbox: tapping a row opens the thread', (tester) async {
    await mountInbox(tester, _ChatRepo()..conversations = [_conv()]);
    await tester.tap(find.text('Rangi'));
    await tester.pumpAndSettle();
    expect(find.text('Thread /chat/7'), findsOneWidget);
  });

  // ── Notifications ───────────────────────────────────────────────────────────

  Future<ProviderContainer> mountNotifications(
    WidgetTester tester, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              platformBrightness: dark ? Brightness.dark : Brightness.light,
            ),
            child: child!,
          ),
          home: const ThNotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('v2 notifications: unread tap marks read; Mark read clears all', (
    tester,
  ) async {
    final container = await mountNotifications(tester);
    final center = container.read(notificationCenterProvider.notifier);
    center.add(
      FixoNotification(
        id: 'n1',
        title: 'Quote received',
        body: 'Bay Builders',
        category: 'jobs',
        receivedAt: DateTime(2026, 11, 3, 9),
      ),
    );
    center.add(
      FixoNotification(
        id: 'n2',
        title: 'Payout sent',
        body: 'Weekly payout',
        category: 'payments',
        receivedAt: DateTime(2026, 11, 3, 9, 10),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mark read'), findsOneWidget);
    expect(center.unreadCount, 2);

    // Tapping an unread row marks just that one read.
    await tester.tap(find.text('Quote received'));
    await tester.pumpAndSettle();
    expect(center.unreadCount, 1);

    // Tapping a read row does nothing (no handler).
    await tester.tap(find.text('Quote received'));
    await tester.pumpAndSettle();
    expect(center.unreadCount, 1);

    await tester.tap(find.text('Mark read'));
    await tester.pumpAndSettle();
    expect(center.unreadCount, 0);
    expect(find.text('Mark read'), findsNothing);
  });

  testWidgets('v2 notifications: filter shows truthful empty state', (
    tester,
  ) async {
    final container = await mountNotifications(tester);
    container
        .read(notificationCenterProvider.notifier)
        .add(
          FixoNotification(
            id: 'n1',
            title: 'Quote received',
            category: 'jobs',
            receivedAt: DateTime(2026, 11, 3, 9),
          ),
        );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    expect(find.text('No Payments notifications'), findsOneWidget);
  });

  testWidgets('v2 notifications: empty inbox uses the no-messages preset', (
    tester,
  ) async {
    await mountNotifications(tester);
    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.text('Mark read'), findsNothing);
  });

  testWidgets('v2 notifications render in light and dark without exceptions', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      final container = await mountNotifications(tester, dark: dark);
      container
          .read(notificationCenterProvider.notifier)
          .add(
            FixoNotification(
              id: 'n$dark',
              title: 'Approve final amount',
              body: r'Aroha Plumbing finished · $261.00',
              category: 'payments',
              receivedAt: DateTime(2026, 11, 3, 9),
            ),
          );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: dark ? 'dark' : 'light');
    }
  });

  testWidgets('v2 notification rows remain ellipsized at 2x text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              platformBrightness: Brightness.dark,
            ),
            child: child!,
          ),
          home: const ThNotificationsScreen(),
        ),
      ),
    );
    container
        .read(notificationCenterProvider.notifier)
        .add(
          FixoNotification(
            id: 'large-text',
            title: 'An unusually long notification title that needs truncation',
            body: 'A detailed notification preview that should wrap or ellipsize cleanly on a narrow screen.',
            category: 'payments',
            receivedAt: DateTime(2026, 11, 3, 9),
          ),
        );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.overflow == TextOverflow.ellipsis,
      ),
      findsAtLeastNWidgets(2),
    );
    expect(tester.takeException(), isNull);
  });

  // ── Profile ─────────────────────────────────────────────────────────────────

  Future<void> mountProfile(
    WidgetTester tester,
    _ProfileRepo profile, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(profile)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              platformBrightness: dark ? Brightness.dark : Brightness.light,
            ),
            child: child!,
          ),
          home: const ThProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('v2 tradie self profile shows payout section (both themes)', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await mountProfile(
        tester,
        _ProfileRepo(const {
          'firstName': 'Mere',
          'lastName': 'Rangi',
          'role': 1,
          'bankAccountVerified': true,
        }),
        dark: dark,
      );
      await tester.tap(find.text('Personal details'));
      await tester.pumpAndSettle();
      expect(find.text('Payout Details'), findsOneWidget);
      expect(find.text('Bank Account Name'), findsOneWidget);
      expect(
        find.text('Verified — used for your weekly payout.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: dark ? 'dark' : 'light');
    }
  });

  testWidgets('v2 homeowner self profile hides tradie sections', (
    tester,
  ) async {
    await mountProfile(
      tester,
      _ProfileRepo(const {'firstName': 'Mere', 'lastName': 'Rangi', 'role': 0}),
    );
    expect(find.text('Tradie Information'), findsNothing);
    expect(find.text('Payout Details'), findsNothing);
    expect(find.text('Homeowner'), findsOneWidget);
  });

  testWidgets('v2 availability toggle saves immediately via endpoint', (
    tester,
  ) async {
    final profile = _ProfileRepo(const {
      'firstName': 'Mere',
      'role': 1,
      'isAvailable': true,
    });
    await mountProfile(tester, profile);
    await tester.tap(find.text('Personal details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Available for jobs'));
    await tester.pumpAndSettle();
    expect(profile.availabilitySaved, isFalse);
  });

  testWidgets('v2 bank number validation enforces NZ format on save', (
    tester,
  ) async {
    final profile = _ProfileRepo(const {
      'firstName': 'Mere',
      'role': 1,
      'bankAccountVerified': true,
    });
    await mountProfile(tester, profile);
    await tester.tap(find.text('Personal details'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Edit profile'));
    await tester.pump();
    // The bank number field is the last TextFormField on the tradie form.
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.last, '12345');
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(profile.updatePayload, isNull);
    expect(find.text('Format: XX-XXXX-XXXXXXX-XX'), findsOneWidget);
  });

  testWidgets('v2 profile keeps the toggle_edit_mode_button contract', (
    tester,
  ) async {
    await mountProfile(
      tester,
      _ProfileRepo(const {'firstName': 'Mere', 'role': 0}),
    );
    expect(find.text('Personal details'), findsOneWidget);
    await tester.tap(find.text('Personal details'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('toggle_edit_mode_button')), findsOneWidget);
    expect(find.bySemanticsLabel('Edit profile'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggle_edit_mode_button')));
    await tester.pump();
    expect(find.bySemanticsLabel('Cancel editing'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggle_edit_mode_button')));
    await tester.pump();
    expect(find.bySemanticsLabel('Edit profile'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
  });

  testWidgets('v2 chat, inbox, profile and settings fit 320px at 2x dark', (
    tester,
  ) async {
    Future<void> mountAt(
      Widget screen, {
      List<Override> overrides = const [],
    }) async {
      tester.view.physicalSize = const Size(320, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2.0),
                platformBrightness: Brightness.dark,
              ),
              child: child!,
            ),
            home: screen,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '$screen at 320px 2x dark',
      );
    }

    await mountAt(
      const ThChatScreen(jobId: '7'),
      overrides: [
        chatRepositoryProvider.overrideWithValue(
          _ChatRepo()..history = [_msg('1')],
        ),
        jobsRepositoryProvider.overrideWithValue(
          _JobsRepo(job: _job('Booked')),
        ),
        externalLauncherProvider.overrideWithValue(_Launcher()),
        profileRepositoryProvider.overrideWithValue(
          _ProfileRepo(const {'role': 0}),
        ),
      ],
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    await mountAt(
      const ThMessagesListScreen(),
      overrides: [
        chatRepositoryProvider.overrideWithValue(
          _ChatRepo()..conversations = [_conv()],
        ),
      ],
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    await mountAt(
      const ThProfileScreen(),
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          _ProfileRepo(const {
            'firstName': 'Mere',
            'lastName': 'Rangi',
            'role': 1,
          }),
        ),
      ],
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    await mountAt(
      const ThSettingsScreen(),
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          _ProfileRepo(const {'role': 0}),
        ),
        localeConfigProvider.overrideWith((ref) async => null),
        authViewModelProvider.overrideWith((ref) => _FakeAuth()),
      ],
    );
  });

  // ── Settings ────────────────────────────────────────────────────────────────

  Future<void> mountSettings(
    WidgetTester tester,
    _ProfileRepo profile, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(profile),
        localeConfigProvider.overrideWith((ref) async => null),
        authViewModelProvider.overrideWith((ref) => _FakeAuth()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              platformBrightness: dark ? Brightness.dark : Brightness.light,
            ),
            child: child!,
          ),
          home: const ThSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('v2 settings rows meet the 48px target (both themes)', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await mountSettings(tester, _ProfileRepo(const {'role': 0}), dark: dark);
      for (final label in [
        'Personal Details',
        'Payment Methods',
        'Notifications',
        'Theme',
        'Help Center',
        'Terms',
      ]) {
        final tile = tester.getSize(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate(
                  (w) => w is ListTile || w is SwitchListTile,
                ),
              )
              .first,
        );
        expect(tile.height, greaterThanOrEqualTo(48), reason: label);
      }
      expect(tester.takeException(), isNull, reason: dark ? 'dark' : 'light');
    }
  });

  testWidgets('v2 theme row opens a picker sheet', (tester) async {
    await mountSettings(tester, _ProfileRepo(const {'role': 0}));
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    // The sheet options sit above the row subtitle, so System appears twice.
    expect(find.text('System'), findsNWidgets(2));
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget); // subtitle now reads Dark
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('v2 payout row only appears for tradies', (tester) async {
    await mountSettings(tester, _ProfileRepo(const {'role': 0}));
    expect(find.text('Payout Details'), findsNothing);

    await mountSettings(tester, _ProfileRepo(const {'role': 1}));
    expect(find.text('Payout Details'), findsOneWidget);
  });

  testWidgets('v2 sign out returns to /auth', (tester) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const ThSettingsScreen()),
        GoRoute(path: '/auth', builder: (_, _) => const Text('AUTH SCREEN')),
      ],
    );
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          _ProfileRepo(const {'role': 0}),
        ),
        localeConfigProvider.overrideWith((ref) async => null),
        authViewModelProvider.overrideWith((ref) => _FakeAuth()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign_out_button')));
    await tester.pumpAndSettle();
    expect(find.text('AUTH SCREEN'), findsOneWidget);
  });
}
