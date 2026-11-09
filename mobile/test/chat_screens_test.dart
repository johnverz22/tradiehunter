import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/network/external_launcher.dart';
import 'package:fixo/repositories/chat_reviews_repository.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/chat_viewmodel.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/views/chat/chat_screen.dart';
import 'package:fixo/views/chat/messages_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Fixtures ─────────────────────────────────────────────────────────────────

ChatMessage _msg(
  String id, {
  String senderId = 'other',
  String senderName = 'Rangi',
  bool sentByMe = false,
  String text = 'hello',
  DateTime? sentAt,
  DateTime? readAt,
}) => ChatMessage(
  id: id,
  jobId: '7',
  senderId: senderId,
  senderName: senderName,
  sentByMe: sentByMe,
  text: text,
  sentAtUtc: sentAt ?? DateTime.utc(2026, 11, 3, 9),
  readAtUtc: readAt,
);

class _ChatRepo extends ChatRepository {
  final messages = StreamController<ChatMessage>.broadcast();
  final reconnected = StreamController<void>.broadcast();

  List<ConversationSummary> conversations = const [];
  bool conversationsThrow = false;
  List<ChatMessage> history = const [];
  bool historyThrow = false;
  bool hubConnected = true;
  bool hubSendThrows = false;
  ChatMessage? restResponse;

  int joinCalls = 0;
  int historyCalls = 0;
  final hubSends = <String>[];
  final restSends = <String>[];
  final reads = <int>[];

  _ChatRepo() : super(Dio(), const FlutterSecureStorage());

  @override
  Stream<ChatMessage> get onNewMessage => messages.stream;
  @override
  Stream<void> get onReconnected => reconnected.stream;

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
  Future<void> connectHub(String baseUrl) async {
    if (!hubConnected) throw StateError('hub unavailable');
  }

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
    restSends.add(text);
    return restResponse ??
        _msg('900', senderId: 'me', sentByMe: true, text: text);
  }

  @override
  void dispose() {
    messages.close();
    reconnected.close();
  }
}

class _JobsRepo extends JobsRepository {
  Job? job;
  JobContact? contact;
  int contactCalls = 0;
  int jobByIdCalls = 0;

  _JobsRepo({this.job, this.contact})
    : super(Dio(), const FlutterSecureStorage());

  @override
  Future<Job?> getJobById(String jobId) async {
    jobByIdCalls++;
    return job;
  }

  @override
  Future<JobContact?> getJobContact(String jobId) async {
    contactCalls++;
    return contact;
  }

  @override
  Future<List<Job>> getMyJobs({String? status}) async =>
      job == null ? const [] : [job!];
}

class _ProfileRepo extends ProfileRepository {
  final Map<String, dynamic> profileMap;
  _ProfileRepo(this.profileMap) : super(Dio(), const FlutterSecureStorage());
  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => profileMap;
}

class _Launcher extends ExternalLauncher {
  final calls = <String>[];
  bool result = true;
  @override
  Future<bool> callPhone(String phoneNumber) async {
    calls.add(phoneNumber);
    return result;
  }
}

Job _job(String status) => Job(
  id: '7',
  title: 'Fix leaking tap',
  category: 'Plumbing',
  suburb: 'Grafton',
  status: status,
  stage: 2,
  homeownerId: 'owner-1',
  matchedTradieId: 'tradie-1',
);

// ── ChatNotifier unit tests ───────────────────────────────────────────────────

void notifierTests() {
  ChatNotifier make(_ChatRepo repo) =>
      ChatNotifier(jobId: '7', repo: repo, myUserId: 'me');

  test('init loads history oldest-first and marks incoming unread', () async {
    final repo = _ChatRepo()
      ..history = [
        _msg('2', text: 'second'),
        _msg('1', text: 'first', readAt: DateTime.utc(2026, 11, 3)),
      ];
    final n = make(repo);
    addTearDown(n.dispose);
    await n.init('http://x');

    expect(n.state.messages.map((m) => m.id), ['1', '2']);
    // msg 1 was already read; msg 2 is unread and not mine → marked.
    expect(repo.reads, [2]);
  });

  test(
    'hub send: server echo swaps the optimistic bubble — no duplicate',
    () async {
      final repo = _ChatRepo();
      final n = make(repo);
      addTearDown(n.dispose);
      await n.init('http://x');

      await n.sendMessage('on my way');
      expect(repo.hubSends, ['on my way']);
      expect(n.state.messages.single.id, startsWith('local-'));

      // Server broadcasts the persisted row back to the group, sender included.
      repo.messages.add(_msg('55', senderId: 'me', text: 'on my way'));
      await Future.microtask(() {});

      expect(n.state.messages.length, 1);
      expect(n.state.messages.single.id, '55');
      expect(n.state.messages.single.sentByMe, isTrue);
    },
  );

  test('send failure flags the bubble and retry delivers it', () async {
    final repo = _ChatRepo()..hubSendThrows = true;
    final n = make(repo);
    addTearDown(n.dispose);
    await n.init('http://x');

    await n.sendMessage('hello?');
    expect(n.state.failedIds, hasLength(1));

    repo.hubSendThrows = false;
    await n.retryMessage(n.state.failedIds.single);
    expect(n.state.failedIds, isEmpty);
    expect(repo.hubSends, ['hello?']);
  });

  test('REST fallback swaps the optimistic bubble for the saved row', () async {
    final repo = _ChatRepo()
      ..hubConnected = false
      ..restResponse = _msg('901', senderId: 'me', text: 'fallback');
    final n = make(repo);
    addTearDown(n.dispose);
    await n.init('http://x');

    await n.sendMessage('fallback');
    expect(repo.restSends, ['fallback']);
    expect(n.state.messages.single.id, '901');
    expect(n.state.failedIds, isEmpty);
  });

  test('reconnect re-joins and reconciles — backfill once, no dupes', () async {
    final repo = _ChatRepo()..history = [_msg('1'), _msg('2')];
    final n = make(repo);
    addTearDown(n.dispose);
    await n.init('http://x');
    expect(repo.joinCalls, 1);

    // Server state advanced while disconnected: msg 3 arrived.
    repo.history = [_msg('3', text: 'new'), _msg('2'), _msg('1')];
    repo.reconnected.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repo.joinCalls, 2);
    expect(n.state.messages.map((m) => m.id), ['1', '2', '3']);

    // A second reconcile must not duplicate anything.
    repo.reconnected.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(n.state.messages.map((m) => m.id), ['1', '2', '3']);
  });

  test(
    'initial load failure surfaces a retryable error, then recovers',
    () async {
      final repo = _ChatRepo()..historyThrow = true;
      final n = make(repo);
      addTearDown(n.dispose);
      await n.init('http://x');
      expect(n.state.loadError, isNotNull);

      repo.historyThrow = false;
      repo.history = [_msg('1')];
      await n.reload();
      expect(n.state.loadError, isNull);
      expect(n.state.messages.single.id, '1');
    },
  );
}

// ── Widget tests ──────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('ChatNotifier', notifierTests);

  group('sentByMe tagging', () {
    test('updateUserId with uppercase GUID correctly tags lowercase senderId',
        () async {
      final repo = _ChatRepo();
      final notifier =
          ChatNotifier(jobId: '7', repo: repo, myUserId: '');
      addTearDown(notifier.dispose);
      repo.history = [_msg('1', senderId: 'abc-123', sentByMe: false)];
      await notifier.init('http://x');

      // Before updateUserId: not mine (empty myUserId).
      expect(notifier.state.messages.single.sentByMe, isFalse);

      // updateUserId with uppercase variant — case-insensitive match.
      notifier.updateUserId('ABC-123');
      expect(notifier.state.messages.single.sentByMe, isTrue);
    });

    test('updateUserId with lowercase GUID correctly tags uppercase senderId',
        () async {
      final repo = _ChatRepo();
      final notifier =
          ChatNotifier(jobId: '7', repo: repo, myUserId: '');
      addTearDown(notifier.dispose);
      repo.history = [_msg('1', senderId: 'ABC-123', sentByMe: false)];
      await notifier.init('http://x');

      expect(notifier.state.messages.single.sentByMe, isFalse);

      notifier.updateUserId('abc-123');
      expect(notifier.state.messages.single.sentByMe, isTrue);
    });

    test('pre-tagged sentByMe=true is preserved after updateUserId', () async {
      final repo = _ChatRepo();
      final notifier =
          ChatNotifier(jobId: '7', repo: repo, myUserId: 'me');
      addTearDown(notifier.dispose);
      // Message is already tagged sentByMe=true from the server.
      repo.history = [_msg('1', senderId: 'other', sentByMe: true)];
      await notifier.init('http://x');

      expect(notifier.state.messages.single.sentByMe, isTrue);

      // Calling updateUserId must not flip the already-tagged message.
      notifier.updateUserId('some-other-id');
      expect(notifier.state.messages.single.sentByMe, isTrue);
    });
  });

  Future<void> mountInbox(
    WidgetTester tester,
    _ChatRepo chat, {
    bool dark = false,
    double scale = 1,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const MessagesListScreen()),
        GoRoute(
          path: '/chat/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Thread ${state.uri.path}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatRepositoryProvider.overrideWithValue(chat)],
        child: MaterialApp.router(
          routerConfig: router,
          theme: dark ? FixoTheme.dark() : FixoTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Messages inbox', () {
    ConversationSummary convo({
      String name = 'Rangi',
      String? preview = 'See you Tuesday',
      bool mine = false,
      int unread = 0,
    }) => ConversationSummary(
      jobId: '7',
      jobTitle: 'Fix leaking tap',
      status: 'Booked',
      otherUserId: 'tradie-1',
      otherFirstName: name,
      lastMessage: preview,
      lastMessageMine: mine,
      lastMessageAtUtc: DateTime.utc(2026, 11, 3, 9),
      unreadCount: unread,
    );

    testWidgets(
      'renders participant name, job, real preview and unread badge',
      (tester) async {
        await mountInbox(
          tester,
          _ChatRepo()..conversations = [convo(unread: 3)],
        );
        expect(find.text('Rangi'), findsOneWidget);
        expect(find.text('Fix leaking tap'), findsOneWidget);
        expect(find.text('See you Tuesday'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      },
    );

    testWidgets('own-message preview is prefixed truthfully', (tester) async {
      await mountInbox(
        tester,
        _ChatRepo()..conversations = [convo(mine: true)],
      );
      expect(find.text('You: See you Tuesday'), findsOneWidget);
    });

    testWidgets('no badge without unread; empty thread shows no fake preview', (
      tester,
    ) async {
      await mountInbox(
        tester,
        _ChatRepo()..conversations = [convo(preview: null, unread: 0)],
      );
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('load failure shows a retryable error state', (tester) async {
      final repo = _ChatRepo()..conversationsThrow = true;
      await mountInbox(tester, repo);
      expect(find.text('Could not load conversations.'), findsOneWidget);

      repo.conversationsThrow = false;
      repo.conversations = [convo()];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Rangi'), findsOneWidget);
    });

    testWidgets('empty inbox is truthful', (tester) async {
      await mountInbox(tester, _ChatRepo());
      expect(find.text('No messages yet'), findsOneWidget);
    });

    testWidgets('tapping a row opens the thread', (tester) async {
      await mountInbox(tester, _ChatRepo()..conversations = [convo()]);
      await tester.tap(find.text('Rangi'));
      await tester.pumpAndSettle();
      expect(find.text('Thread /chat/7'), findsOneWidget);
    });

    testWidgets('320px at 2.0 text scale, dark theme, no overflow', (
      tester,
    ) async {
      await mountInbox(
        tester,
        _ChatRepo()..conversations = [convo(unread: 102)],
        dark: true,
        scale: 2,
        width: 320,
      );
      expect(find.text('99+'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Chat screen', () {
    Future<void> mountChat(
      WidgetTester tester,
      _ChatRepo chat,
      _JobsRepo jobs, {
      _Launcher? launcher,
      _ProfileRepo? profile,
      bool dark = false,
      double scale = 1,
      double width = 390,
    }) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(chat),
            jobsRepositoryProvider.overrideWithValue(jobs),
            externalLauncherProvider.overrideWithValue(launcher ?? _Launcher()),
            profileRepositoryProvider.overrideWithValue(
              profile ?? _ProfileRepo(const {'role': 0}),
            ),
          ],
          child: MaterialApp(
            theme: dark ? FixoTheme.dark() : FixoTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const ChatScreen(jobId: '7'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'participant-first header: contact name leads, job is the subtitle',
      (tester) async {
        await mountChat(
          tester,
          _ChatRepo(),
          _JobsRepo(
            job: _job('Booked'),
            contact: const JobContact(userId: 'tradie-1', firstName: 'Rangi'),
          ),
        );
        expect(find.text('Rangi'), findsOneWidget);
        expect(find.text('Fix leaking tap'), findsOneWidget);
      },
    );

    testWidgets('call is shown only when the server authorized a number', (
      tester,
    ) async {
      final launcher = _Launcher();
      await mountChat(
        tester,
        _ChatRepo(),
        _JobsRepo(
          job: _job('Booked'),
          contact: const JobContact(
            userId: 'tradie-1',
            firstName: 'Rangi',
            phoneNumber: '+64 21 555 010',
          ),
        ),
        launcher: launcher,
      );
      await tester.tap(find.byTooltip('Call'));
      expect(launcher.calls, ['+64 21 555 010']);
    });

    testWidgets('call is hidden without a phone number', (tester) async {
      await mountChat(
        tester,
        _ChatRepo(),
        _JobsRepo(
          job: _job('Booked'),
          contact: const JobContact(userId: 'tradie-1', firstName: 'Rangi'),
        ),
      );
      expect(find.byTooltip('Call'), findsNothing);
    });

    testWidgets('call is hidden pre-Booked (contact endpoint is NotFound)', (
      tester,
    ) async {
      final jobs = _JobsRepo(job: _job('Matched'));
      await mountChat(tester, _ChatRepo(), jobs);
      expect(find.byTooltip('Call'), findsNothing);
      // Matched is not a contactable status — the endpoint is not even asked.
      expect(jobs.contactCalls, 0);
    });

    testWidgets('quick replies populate the composer without sending', (
      tester,
    ) async {
      final chat = _ChatRepo();
      await mountChat(tester, chat, _JobsRepo(job: _job('Booked')));
      await tester.tap(find.text('That works for me.'));
      await tester.pump();
      expect(find.text('That works for me.'), findsWidgets);
      expect(chat.hubSends, isEmpty);
      expect(chat.restSends, isEmpty);
    });

    testWidgets('send goes through the existing hub path', (tester) async {
      final chat = _ChatRepo();
      await mountChat(tester, chat, _JobsRepo(job: _job('Booked')));
      await tester.enterText(find.byType(TextField), 'see you then');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      expect(chat.hubSends, ['see you then']);
      expect(find.text('see you then'), findsOneWidget);
    });

    testWidgets('failed send shows retry; tapping it redelivers', (
      tester,
    ) async {
      final chat = _ChatRepo()..hubSendThrows = true;
      await mountChat(tester, chat, _JobsRepo(job: _job('Booked')));
      await tester.enterText(find.byType(TextField), 'ping');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Not sent — tap to retry'), findsOneWidget);

      chat.hubSendThrows = false;
      await tester.tap(find.text('Not sent — tap to retry'));
      await tester.pumpAndSettle();
      expect(chat.hubSends, ['ping']);
      expect(find.text('Not sent — tap to retry'), findsNothing);
    });

    testWidgets('Disputed jobs lock the composer, matching the server', (
      tester,
    ) async {
      await mountChat(tester, _ChatRepo(), _JobsRepo(job: _job('Disputed')));
      expect(find.text('Messaging is disabled for this job.'), findsOneWidget);
      expect(find.byTooltip('Send message'), findsNothing);
      expect(find.text('Chat is closed — job disputed.'), findsOneWidget);
    });

    testWidgets('history failure shows a retryable error', (tester) async {
      final chat = _ChatRepo()..historyThrow = true;
      await mountChat(tester, chat, _JobsRepo(job: _job('Booked')));
      expect(find.text('Could not load messages.'), findsOneWidget);
    });

    testWidgets('incoming messages render with sender name and time', (
      tester,
    ) async {
      final chat = _ChatRepo()
        ..history = [
          _msg('2', text: 'Running 10 late', senderName: 'Rangi'),
          _msg(
            '1',
            text: 'Morning',
            senderId: 'me',
            sentByMe: true,
            readAt: DateTime.utc(2026, 11, 3, 9, 1),
          ),
        ];
      await mountChat(tester, chat, _JobsRepo(job: _job('Booked')));
      expect(find.text('Running 10 late'), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);
      // Unread incoming message was marked read via the hub.
      expect(chat.reads, [2]);
    });

    testWidgets('320px at 2.0 text scale, dark theme, no overflow', (
      tester,
    ) async {
      await mountChat(
        tester,
        _ChatRepo()..history = [_msg('1', text: 'Hi there')],
        _JobsRepo(
          job: _job('Booked'),
          contact: const JobContact(
            userId: 't',
            firstName: 'Rangi',
            phoneNumber: '+64 21 555 010',
          ),
        ),
        dark: true,
        scale: 2,
        width: 320,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
