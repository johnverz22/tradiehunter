import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/chat_reviews_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/views/chat/messages_list_screen.dart';
import 'package:fixo/views/main_layout.dart';
import 'package:fixo/views/widgets/custom_bottom_nav_bar.dart';
import 'package:fixo/widgets/fixo_states.dart';

class _FakeProfileRepo extends ProfileRepository {
  final int role;
  _FakeProfileRepo({this.role = 0}) : super(Dio(), const FlutterSecureStorage());

  @override
  Future<Map<String, dynamic>> getCurrentProfile() async {
    return {'id': 'user-1', 'role': role, 'fullName': 'Test User'};
  }
}

class _FakeChatRepo extends ChatRepository {
  final _msgStream = StreamController<ChatMessage>.broadcast();
  final _reconnectStream = StreamController<void>.broadcast();

  _FakeChatRepo() : super(Dio(), const FlutterSecureStorage());

  @override
  Stream<ChatMessage> get onNewMessage => _msgStream.stream;
  @override
  Stream<void> get onReconnected => _reconnectStream.stream;

  @override
  Future<List<ConversationSummary>> getConversations() async {
    return [
      ConversationSummary(
        jobId: 'job-1',
        jobTitle: 'Fix Leaking Tap',
        status: 'Booked',
        otherUserId: 'alex-1',
        otherFirstName: 'Alex',
        lastMessage: 'On my way!',
        lastMessageAtUtc: DateTime.utc(2026, 10, 30, 9, 0),
        unreadCount: 1,
      ),
    ];
  }

  @override
  Future<ChatHistoryResult> getMessages(
    String jobId, {
    int? beforeId,
    int pageSize = 30,
  }) async {
    return ChatHistoryResult(
      messages: [
        ChatMessage(
          id: 'msg-1',
          jobId: jobId,
          senderId: 'alex-1',
          senderName: 'Alex',
          text: 'On my way!',
          sentAtUtc: DateTime.utc(2026, 10, 30, 9, 0),
          sentByMe: false,
        ),
      ],
      hasMore: false,
    );
  }
}

void main() {
  group('iPad Responsive Layout (V16-18)', () {
    testWidgets('MasterDetailLayout switches at 744pt breakpoint', (tester) async {
      Widget buildTest(double width) {
        return MediaQuery(
          data: MediaQueryData(size: Size(width, 1000)),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: MasterDetailLayout(
              master: Text('Master Panel'),
              detail: Text('Detail Panel'),
              detailVisible: true,
            ),
          ),
        );
      }

      // Phone portrait (390pt) -> only master rendered
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTest(390));
      expect(find.text('Master Panel'), findsOneWidget);
      expect(find.text('Detail Panel'), findsNothing);

      // iPad mini portrait (744pt) -> both master (360px) and detail rendered
      tester.view.physicalSize = const Size(744, 1000);
      await tester.pumpWidget(buildTest(744));
      expect(find.text('Master Panel'), findsOneWidget);
      expect(find.text('Detail Panel'), findsOneWidget);

      final masterBox = tester.renderObject<RenderBox>(find.text('Master Panel'));
      expect(masterBox.size.width, lessThanOrEqualTo(360.0));
    });

    testWidgets('MasterDetailLayout renders emptyDetail when detailVisible is false', (tester) async {
      tester.view.physicalSize = const Size(820, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(820, 1000)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MasterDetailLayout(
              master: Text('Master Panel'),
              detail: Text('Detail Panel'),
              emptyDetail: Text('Select an item'),
              detailVisible: false,
            ),
          ),
        ),
      );

      expect(find.text('Master Panel'), findsOneWidget);
      expect(find.text('Select an item'), findsOneWidget);
      expect(find.text('Detail Panel'), findsNothing);
    });

    testWidgets('MainLayout switches to left rail navigation at 1024pt', (tester) async {
      Widget buildShell(double width) {
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            ShellRoute(
              builder: (context, state, child) => MainLayout(child: child),
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const Text('Home Screen'),
                ),
              ],
            ),
          ],
        );

        return ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(_FakeProfileRepo(role: 0)),
          ],
          child: MaterialApp.router(routerConfig: router),
        );
      }

      // Tablet portrait (820pt) -> uses CustomBottomNavBar
      tester.view.physicalSize = const Size(820, 1180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildShell(820));
      await tester.pumpAndSettle();
      expect(find.byType(CustomBottomNavBar), findsOneWidget);

      // iPad landscape (1024pt+) -> left navigation rail replaces bottom bar
      tester.view.physicalSize = const Size(1024, 820);
      await tester.pumpWidget(buildShell(1024));
      await tester.pumpAndSettle();

      expect(find.byType(CustomBottomNavBar), findsNothing);
      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets('MessagesListScreen renders master-detail at 744pt and selects chat', (tester) async {
      tester.view.physicalSize = const Size(820, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final chatRepo = _FakeChatRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(chatRepo),
            profileRepositoryProvider.overrideWithValue(_FakeProfileRepo(role: 0)),
          ],
          child: const MaterialApp(
            home: MessagesListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Master list has the conversation
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Fix Leaking Tap'), findsOneWidget);

      // Detail panel has placeholder before selection
      expect(find.text('Select a conversation'), findsOneWidget);

      // Tap conversation to select it in wide layout
      await tester.tap(find.text('Alex'));
      await tester.pumpAndSettle();

      // Detail pane now shows the chat
      expect(find.text('Select a conversation'), findsNothing);
      expect(find.text('On my way!'), findsWidgets);
    });
  });
}
