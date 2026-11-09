import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/chat_reviews_repository.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/views/profile/public_profile_screen.dart';
import 'package:fixo/widgets/rating_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileFixture extends ProfileRepository {
  final String viewer;
  ProfileFixture(this.viewer) : super(Dio(), const FlutterSecureStorage());
  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => {'id': viewer};
}

class ReviewsFixture extends ReviewsRepository {
  bool missing = false;
  bool failReviews = false;
  ReviewsFixture() : super(Dio(), const FlutterSecureStorage());
  @override
  Future<UserProfile?> getProfile(String userId) async => missing
      ? null
      : UserProfile.fromJson({
          'id': userId,
          'firstName': 'Actual',
          'lastName': 'Person',
          'role': 'Tradie',
          'reviewCount': 0,
          'averageRating': 0,
        });
  @override
  Future<ReviewPage> getReviewsForUser(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    if (failReviews) throw const ProfileApiException('Could not load reviews.');
    return const ReviewPage(items: [], totalCount: 0, page: 1, pageSize: 10);
  }
}

class JobsFixture extends JobsRepository {
  final List<Job> jobs;
  JobsFixture(this.jobs) : super(Dio(), const FlutterSecureStorage());
  @override
  Future<List<Job>> getMyJobs({String? status}) async => jobs;
}

Job job(String id, String status, String homeowner, String tradie) => Job(
  id: id,
  title: 'Customer title $id',
  category: 'Plumbing',
  suburb: '',
  status: status,
  stage: 0,
  homeownerId: homeowner,
  matchedTradieId: tradie,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> mount(
    WidgetTester tester, {
    String viewer = 'viewer',
    bool dark = false,
    List<Job> jobs = const [],
    bool missing = false,
    bool failReviews = false,
  }) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reviews = ReviewsFixture()
      ..missing = missing
      ..failReviews = failReviews;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(ProfileFixture(viewer)),
          reviewsRepositoryProvider.overrideWithValue(reviews),
          jobsRepositoryProvider.overrideWithValue(JobsFixture(jobs)),
        ],
        child: MaterialApp(
          theme: dark ? FixoTheme.dark() : FixoTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const PublicProfileScreen(profileId: 'target', isTradie: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets('visitor cannot edit another profile dark=$dark', (
      tester,
    ) async {
      await mount(tester, dark: dark);
      expect(find.text('Edit Profile'), findsNothing);
      expect(
        find.text(
          'No reviews yet — reviews appear here after a completed job.',
        ),
        findsOneWidget,
      );
      // Report/Block live in the overflow menu now.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Report user'), findsOneWidget);
      expect(find.text('Block user'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('owner can edit but not review themselves dark=$dark', (
      tester,
    ) async {
      await mount(tester, viewer: 'target', dark: dark);
      await tester.scrollUntilVisible(find.text('Edit Profile'), 250);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Leave a review'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('missing profile has no invented identity dark=$dark', (
      tester,
    ) async {
      await mount(tester, missing: true, dark: dark);
      expect(find.text('Profile unavailable'), findsOneWidget);
      expect(find.text('Member'), findsNothing);
      expect(find.text('Edit Profile'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed review fetch is not a no-reviews empty state', (
    tester,
  ) async {
    await mount(tester, failReviews: true);
    await tester.scrollUntilVisible(
      find.text('Could not load reviews. Try again.'),
      250,
    );
    expect(
      find.text('No reviews yet — reviews appear here after a completed job.'),
      findsNothing,
    );
    expect(find.text('Could not load reviews. Try again.'), findsOneWidget);
  });

  for (final eligible in [false, true]) {
    testWidgets('review selects only completed shared job eligible=$eligible', (
      tester,
    ) async {
      await mount(
        tester,
        jobs: [
          job('unrelated', 'Completed', 'viewer', 'someone-else'),
          job('active', 'InProgress', 'viewer', 'target'),
          job('legacy', 'Complete', 'viewer', 'target'),
          if (eligible) job('shared', 'Completed', 'viewer', 'target'),
        ],
      );
      await tester.scrollUntilVisible(find.text('Leave a review'), 250);
      await tester.tap(find.text('Leave a review'));
      await tester.pumpAndSettle();
      if (eligible) {
        expect(
          tester.widget<RatingSheet>(find.byType(RatingSheet)).jobId,
          'shared',
        );
      } else {
        expect(find.byType(RatingSheet), findsNothing);
        expect(
          find.text('Reviews unlock after a completed job.'),
          findsOneWidget,
        );
      }
    });
  }
}
