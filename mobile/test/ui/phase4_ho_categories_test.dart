import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/ui/homeowner/ho_categories_screen.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/theme_mode_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _JobsFixture extends JobsRepository {
  _JobsFixture() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<List<ServiceOption>> getServiceCatalog() async => const [
    ServiceOption(id: 1, name: 'Tap repair', category: 'Plumbing'),
    ServiceOption(id: 2, name: 'Blocked drain', category: 'Plumbing'),
    ServiceOption(id: 3, name: 'Switch repair', category: 'Electrical'),
  ];
}

void main() {
  testWidgets('categories search catalog and preserve category extra', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/categories',
      routes: [
        GoRoute(
          path: '/categories',
          builder: (_, _) => const HoCategoriesScreen(),
        ),
        GoRoute(
          path: '/find-tradie',
          builder: (_, state) =>
              Scaffold(body: Text('Category seed: ${state.extra}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsRepositoryProvider.overrideWithValue(_JobsFixture()),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plumbing'), findsOneWidget);
    expect(find.text('2 active services'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'elect');
    await tester.pump();
    expect(find.text('Electrical'), findsOneWidget);
    expect(find.text('Plumbing'), findsNothing);
    await tester.tap(find.text('Electrical'));
    await tester.pumpAndSettle();
    expect(find.text('Category seed: Electrical'), findsOneWidget);
  });
}
