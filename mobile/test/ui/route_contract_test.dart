import 'package:fixo/router/app_router.dart';
import 'package:fixo/router/notification_route.dart';
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
  test('optional route extras reject null and wrong payload types safely', () {
    expect(routeCategorySeed('Plumbing'), 'Plumbing');
    expect(routeCategorySeed(null), isNull);
    expect(routeCategorySeed(42), isNull);
    expect(routeGstLabel('incl. GST'), 'incl. GST');
    expect(routeGstLabel(null), isNull);
    expect(routeGstLabel(const <String>['wrong']), isNull);
    expect(routeVerificationEmail('person@example.com'), 'person@example.com');
    expect(routeVerificationEmail('   '), isNull);
    expect(routeVerificationEmail(42), isNull);
    expect(
      routeRoleSelectExtra((userId: 'u-1', registrationToken: 'one-time')),
      (userId: 'u-1', registrationToken: 'one-time'),
    );
    expect(routeRoleSelectExtra(null), isNull);
    expect(routeRoleSelectExtra('wrong'), isNull);
  });

  test('notification deep links retain their existing shell destinations', () {
    expect(routeForMessageType('chat'), '/messages');
    expect(routeForMessageType('job_status'), '/messages');
    expect(routeForMessageType('match'), '/jobs');
    expect(routeForMessageType(null), '/messages');
    expect(routeForMessageType('unknown'), '/messages');
  });

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
