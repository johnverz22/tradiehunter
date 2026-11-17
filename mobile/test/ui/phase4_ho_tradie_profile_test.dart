import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/chat_reviews_repository.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fixo/ui/homeowner/ho_tradie_profile_mapper.dart';
import 'package:fixo/ui/homeowner/ho_tradie_profile_actions.dart';
import 'package:fixo/ui/homeowner/ho_tradie_profile_header.dart';
import 'package:fixo/ui/homeowner/ho_tradie_profile_providers.dart';
import 'package:fixo/ui/homeowner/ho_tradie_profile_sections.dart';
import 'package:fixo/ui/design/th_scope.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _RequestJobsRepository extends JobsRepository {
  _RequestJobsRepository() : super(Dio(), const FlutterSecureStorage());

  String? requestedJobId;
  String? requestedTradieId;
  String? requestedMessage;

  @override
  Future<JobOffer> requestTradieForJob(
    String jobId,
    String tradieId, {
    String? message,
  }) async {
    requestedJobId = jobId;
    requestedTradieId = tradieId;
    requestedMessage = message;
    return JobOffer(
      id: 'offer-1',
      jobId: jobId,
      tradieId: tradieId,
      offeredAtUtc: DateTime.utc(2026),
      expiresAtUtc: DateTime.utc(2026, 1, 2),
      response: 'Pending',
      stage: 'Auto',
      kind: 'Direct',
      message: message,
    );
  }
}

void main() {
  group('tradie profile mapper', () {
    test('rating is shown only when both score and positive count exist', () {
      expect(
        thHasRating(
          const UserProfile(
            id: 't1',
            firstName: 'Aroha',
            lastName: 'Ngata',
            role: 'Tradie',
            averageRating: 4.8,
            reviewCount: 3,
          ),
        ),
        isTrue,
      );
      expect(
        thHasRating(
          const UserProfile(
            id: 't1',
            firstName: 'Aroha',
            lastName: 'Ngata',
            role: 'Tradie',
            averageRating: null,
            reviewCount: 3,
          ),
        ),
        isFalse,
      );
    });

    test('stats use real job row values and omit absent values', () {
      const profile = UserProfile(
        id: 't1',
        firstName: 'Aroha',
        lastName: 'Ngata',
        role: 'Tradie',
        averageRating: 4.8,
        reviewCount: 3,
      );
      expect(thProfileStats(profile: profile), hasLength(1));
      final stats = thProfileStats(
        profile: profile,
        jobEntry: TradieListEntry(
          tradieId: 't1',
          name: 'Aroha Ngata',
          initials: 'AN',
          verified: false,
          insured: false,
          available: false,
          rating: 4.8,
          reviewCount: 3,
          completedJobs: 12,
          distanceKm: 2.4,
          distance: '2.4 km away',
          hourlyRate: Decimal.parse('85'),
        ),
      );
      expect(stats.map((stat) => (stat.value, stat.label)), [
        ('4.8', '3 reviews'),
        ('12', 'Jobs done'),
        ('2.4 km', 'Away'),
      ]);
    });

    test('rate, trust and profile copy are omitted when missing', () {
      const profile = UserProfile(
        id: 't1',
        firstName: '',
        lastName: '',
        role: 'Tradie',
        averageRating: null,
        reviewCount: null,
      );
      expect(thProfileName(profile), 'Name unavailable');
      expect(thProfileSubtitle(profile), 'Tradie');
      expect(thRateLabel(null), isNull);
      expect(thHasTrustDetails(profile), isFalse);
    });

    test(
      'completed shared job and requestable jobs respect status and parties',
      () {
        Job job(String id, String status, String homeowner, String tradie) =>
            Job(
              id: id,
              title: 'Fix tap',
              category: 'Plumbing',
              suburb: 'Grey Lynn',
              status: status,
              stage: 0,
              homeownerId: homeowner,
              matchedTradieId: tradie,
              flowVersion: Job.flowVersionV2,
            );

        final jobs = [
          job('open', 'Requested', 'h1', 't1'),
          job('other', 'Completed', 'h2', 't2'),
          job('done', 'Completed', 'h1', 't1'),
        ];
        expect(
          thCompletedSharedJob(jobs, viewerId: 'h1', profileId: 't1')?.id,
          'done',
        );
        expect(
          thCompletedSharedJob(jobs, viewerId: 'h9', profileId: 't1'),
          isNull,
        );
        expect(thRequestableJobs(jobs).map((job) => job.id), ['open']);
      },
    );
  });

  testWidgets('profile sections render without a job and with reviews', (
    tester,
  ) async {
    const profile = UserProfile(
      id: 't1',
      firstName: 'Aroha',
      lastName: 'Ngata',
      role: 'Tradie',
      averageRating: 4.8,
      reviewCount: 2,
      bio: 'Local plumber',
    );
    final review = Review(
      id: 'r1',
      jobId: 1,
      reviewerId: 'h1',
      reviewerName: 'Mere',
      revieweeId: 't1',
      rating: 5,
      comment: 'Great work',
      createdAtUtc: DateTime.utc(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          thReviewsProvider('t1').overrideWith((ref) => _ReviewsForTest()),
        ],
        child: MaterialApp(
          home: ThScope(
            themeMode: ThemeMode.light,
            child: Scaffold(
              body: Column(
                children: [
                  ThProfileHeader(profile: profile),
                  ThProfileAboutCard(profile: profile),
                  ThProfileReviews(
                    state: ThReviewsState(reviews: [review], hasMore: false),
                    onLoadMore: _noop,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Aroha Ngata'), findsOneWidget);
    expect(find.text('Local plumber'), findsOneWidget);
    expect(find.text('Great work'), findsOneWidget);
    expect(
      find.text('No reviews yet — reviews appear here after a completed job.'),
      findsNothing,
    );
  });

  testWidgets('job context exposes the request action', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ThScope(
            themeMode: ThemeMode.light,
            child: Scaffold(
              body: ThTradieProfileActions(
                profileId: 't1',
                isTradie: true,
                viewerRole: 0,
                jobId: 'j1',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('request_this_tradie_button')), findsOneWidget);
    expect(find.text('Request this tradie'), findsOneWidget);
  });

  testWidgets(
    'direct request posts job and tradie ids then opens request route',
    (tester) async {
      final jobs = _RequestJobsRepository();
      final router = GoRouter(
        initialLocation: '/tradie/t1?jobId=j1',
        routes: [
          GoRoute(
            path: '/tradie/:id',
            builder: (_, state) => Scaffold(
              body: ThScope(
                themeMode: ThemeMode.light,
                child: ThTradieProfileActions(
                  profileId: state.pathParameters['id']!,
                  isTradie: true,
                  viewerRole: 0,
                  jobId: state.uri.queryParameters['jobId'],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/jobs/:jobId/request',
            builder: (_, state) => Scaffold(
              body: Text('Request sent for ${state.pathParameters['jobId']}'),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [jobsRepositoryProvider.overrideWithValue(jobs)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.tap(find.byKey(const Key('request_this_tradie_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();

      expect(jobs.requestedJobId, 'j1');
      expect(jobs.requestedTradieId, 't1');
      expect(jobs.requestedMessage, '');
      expect(find.text('Request sent for j1'), findsOneWidget);
    },
  );
}

void _noop() {}

class _ReviewsForTest extends ThReviewsNotifier {
  _ReviewsForTest() : super(_ReviewsRepoForTest(), 't1');
}

class _ReviewsRepoForTest extends ReviewsRepository {
  _ReviewsRepoForTest() : super(Dio(), const FlutterSecureStorage());
}
