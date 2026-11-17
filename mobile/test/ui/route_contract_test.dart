import 'package:fixo/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Iterable<String> _paths(Iterable<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      if (!route.path.startsWith('/debug/')) yield route.path;
      yield* _paths(route.routes);
    } else if (route is ShellRoute) {
      yield* _paths(route.routes);
    }
  }
}

void main() {
  test('router path snapshot preserves the mobile route contract', () {
    expect(_paths(appRouter.configuration.routes).toList(), <String>[
      '/',
      '/onboarding',
      '/auth',
      '/signup',
      '/role-select',
      '/verify-email',
      '/categories',
      '/find-tradie',
      '/notifications',
      '/jobs/new',
      '/jobs/:jobId/matching',
      '/jobs/:jobId/request',
      '/jobs/:jobId/tradies',
      '/jobs/:jobId/quotes',
      '/tradie/requests/:requestId',
      '/chat/:jobId',
      '/jobs/:jobId/payment',
      '/jobs/:jobId/payment/status',
      '/jobs/:jobId/detail',
      '/jobs/:jobId/dispute',
      '/tradie/jobs/:jobId',
      '/tradie/onboarding',
      '/tradie/:id',
      '/users/:id',
      '/home',
      '/tradie',
      '/jobs',
      '/messages',
      '/profile',
      '/settings',
    ]);
    expect(
      _paths(appRouter.configuration.routes),
      isNot(contains('/jobs/:jobId/edit')),
      reason: 'Draft edit remains the documented F-3 gap.',
    );
  });
}
