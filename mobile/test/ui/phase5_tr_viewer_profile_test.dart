// Phase 5.8: a tradie viewing another tradie's public profile gets the v2
// screen (previously role-gated to v1); homeowner viewers are unchanged.
import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/chat_reviews_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/ui/homeowner/ho_tradie_profile_screen.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart' show reviewsRepositoryProvider;
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/viewmodels/theme_mode_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Reviews extends ReviewsRepository {
  _Reviews() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<UserProfile?> getProfile(String userId) async => const UserProfile(
    id: 't2',
    firstName: 'Aroha',
    lastName: 'Ngata',
    role: 'Tradie',
    averageRating: 4.8,
    reviewCount: 3,
  );

  @override
  Future<ReviewPage> getReviewsForUser(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) async => const ReviewPage(items: [], totalCount: 0, page: 1, pageSize: 10);
}

class _DummyProfileRepo extends ProfileRepository {
  _DummyProfileRepo(this.profile) : super(Dio(), const FlutterSecureStorage());
  final Map<String, dynamic> profile;
  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => profile;
}

class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier(Map<String, dynamic> profile)
    : super(_DummyProfileRepo(profile)) {
    state = ProfileState(profile: profile);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final role in [0, 1]) {
    testWidgets('viewer role $role gets the v2 tradie profile', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewsRepositoryProvider.overrideWithValue(_Reviews()),
            themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
            profileViewModelProvider.overrideWith(
              (ref) => _FakeProfileNotifier({'id': 'viewer-1', 'role': role}),
            ),
          ],
          child: const MaterialApp(home: ThTradieProfileRoute(profileId: 't2')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ho_tradie_profile')), findsOneWidget);
    });
  }
}
