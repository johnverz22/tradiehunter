import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/chat_reviews_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/ui/homeowner/ho_public_profile_screen.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/viewmodels/theme_mode_viewmodel.dart';

class _ReviewsFixture extends ReviewsRepository {
  _ReviewsFixture({this.profile, this.reviews = const []})
    : super(Dio(), const FlutterSecureStorage());

  final UserProfile? profile;
  final List<Review> reviews;

  @override
  Future<UserProfile?> getProfile(String userId) async => profile;

  @override
  Future<ReviewPage> getReviewsForUser(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) async => ReviewPage(
    items: reviews,
    totalCount: reviews.length,
    page: page,
    pageSize: pageSize,
  );
}

class _ReviewsErrorFixture extends ReviewsRepository {
  _ReviewsErrorFixture() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<UserProfile?> getProfile(String userId) async {
    throw Exception('Failed to load');
  }

  @override
  Future<ReviewPage> getReviewsForUser(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) async => const ReviewPage(items: [], totalCount: 0, page: 1, pageSize: 10);
}

class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier(Map<String, dynamic>? profile)
    : super(_DummyProfileRepo(profile)) {
    state = ProfileState(profile: profile);
  }
}

class _DummyProfileRepo extends ProfileRepository {
  _DummyProfileRepo(this.profile) : super(Dio(), const FlutterSecureStorage());
  final Map<String, dynamic>? profile;
  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => profile ?? {};
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final sampleHomeowner = UserProfile(
    id: 'ho-1',
    firstName: 'Sarah',
    lastName: 'Connor',
    role: 'Homeowner',
    bio: 'Renovating my 1920s bungalow in Ponsonby.',
    memberSinceUtc: DateTime.utc(2025, 3, 15),
    averageRating: 5.0,
    reviewCount: 1,
  );

  final sampleReview = Review(
    id: 'rev-1',
    jobId: 101,
    reviewerId: 'tr-1',
    reviewerName: 'Dave Sparks',
    revieweeId: 'ho-1',
    rating: 5,
    comment: 'Great homeowner to work with, prompt payment!',
    createdAtUtc: DateTime.utc(2025, 4, 1),
  );

  testWidgets('renders homeowner profile with header, bio, and reviews', (
    tester,
  ) async {
    final fixture = _ReviewsFixture(
      profile: sampleHomeowner,
      reviews: [sampleReview],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewsRepositoryProvider.overrideWithValue(fixture),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
          profileViewModelProvider.overrideWith(
            (ref) => _FakeProfileNotifier({'id': 'tr-1', 'role': 1}),
          ),
        ],
        child: const MaterialApp(
          home: HoPublicProfileScreen(profileId: 'ho-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sarah Connor'), findsOneWidget);
    expect(find.text('Homeowner'), findsOneWidget);
    expect(find.byKey(const Key('profile_member_since')), findsOneWidget);
    expect(find.textContaining('March 2025'), findsOneWidget);
    expect(find.byKey(const Key('profile_about_eyebrow')), findsOneWidget);
    expect(
      find.text('Renovating my 1920s bungalow in Ponsonby.'),
      findsOneWidget,
    );
    expect(find.text('RECENT REVIEWS'), findsOneWidget);
    expect(
      find.text('Great homeowner to work with, prompt payment!'),
      findsOneWidget,
    );
    expect(find.text('Dave Sparks'), findsOneWidget);

    // Non-owner viewer sees the actions menu with Report / Block
    expect(find.byTooltip('More actions'), findsOneWidget);
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.text('Report user'), findsOneWidget);
    expect(find.text('Block user'), findsOneWidget);
  });

  testWidgets('renders New to Fixo and no reviews note when rating is absent', (
    tester,
  ) async {
    const unratedHomeowner = UserProfile(
      id: 'ho-2',
      firstName: 'Tom',
      lastName: 'Hanks',
      role: 'Homeowner',
      averageRating: null,
      reviewCount: 0,
    );
    final fixture = _ReviewsFixture(profile: unratedHomeowner, reviews: []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewsRepositoryProvider.overrideWithValue(fixture),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
          profileViewModelProvider.overrideWith(
            (ref) => _FakeProfileNotifier({'id': 'ho-2', 'role': 0}),
          ),
        ],
        child: const MaterialApp(
          home: HoPublicProfileScreen(profileId: 'ho-2'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tom Hanks'), findsOneWidget);
    expect(find.text('Homeowner'), findsOneWidget);
    expect(find.byKey(const Key('profile_new_to_fixo')), findsOneWidget);
    expect(
      find.text('No reviews yet — reviews appear here after a completed job.'),
      findsOneWidget,
    );
    // Own profile viewer does not see the report/block menu
    expect(find.byTooltip('More actions'), findsNothing);
  });

  testWidgets('renders empty state when profile is null', (tester) async {
    final fixture = _ReviewsFixture(profile: null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewsRepositoryProvider.overrideWithValue(fixture),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: const MaterialApp(
          home: HoPublicProfileScreen(profileId: 'missing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile unavailable'), findsOneWidget);
  });

  testWidgets('renders error state on failure', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewsRepositoryProvider.overrideWithValue(_ReviewsErrorFixture()),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: const MaterialApp(home: HoPublicProfileScreen(profileId: 'err')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load profile'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
