import 'package:dio/dio.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/chat_reviews_repository.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/locale_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/views/profile/public_profile_screen.dart';
import 'package:fixo/views/profile_screen.dart';
import 'package:fixo/views/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileFixture extends ProfileRepository {
  final Map<String, dynamic> self;
  bool? availabilitySaved;
  Map<String, dynamic>? updatePayload;

  ProfileFixture(this.self) : super(Dio(), const FlutterSecureStorage());

  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => self;

  @override
  Future<void> updateAvailability(bool isAvailable) async {
    availabilitySaved = isAvailable;
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    updatePayload = profileData;
  }
}

class ReviewsFixture extends ReviewsRepository {
  final Map<String, dynamic> profileJson;
  ReviewsFixture(this.profileJson) : super(Dio(), const FlutterSecureStorage());
  @override
  Future<UserProfile?> getProfile(String userId) async =>
      UserProfile.fromJson({...profileJson, 'id': userId});
  @override
  Future<ReviewPage> getReviewsForUser(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) async => const ReviewPage(items: [], totalCount: 0, page: 1, pageSize: 10);
}

class ChatFixture extends ChatRepository {
  final List<ConversationSummary> convs;
  ChatFixture(this.convs) : super(Dio(), const FlutterSecureStorage());
  @override
  Future<List<ConversationSummary>> getConversations() async => convs;
}

class JobsFixture extends JobsRepository {
  final List<Job> jobs;
  String? requestedJobId;
  String? requestedTradieId;
  JobsFixture(this.jobs) : super(Dio(), const FlutterSecureStorage());
  @override
  Future<List<Job>> getMyJobs({String? status}) async =>
      jobs.where((j) => status == null || j.status == status).toList();
  @override
  Future<bool> requestTradie(String jobId, String tradieId) async {
    requestedJobId = jobId;
    requestedTradieId = tradieId;
    return true;
  }
}

Job job(String id, String status, String homeowner, String tradie) => Job(
  id: id,
  title: 'Job $id',
  category: 'Plumbing',
  suburb: 'Auckland',
  status: status,
  stage: 0,
  homeownerId: homeowner,
  matchedTradieId: tradie,
);

ConversationSummary conv(String jobId, String status, String otherUserId) =>
    ConversationSummary(
      jobId: jobId,
      jobTitle: 'Job $jobId',
      status: status,
      otherUserId: otherUserId,
      otherFirstName: 'Other',
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Map<String, dynamic> viewer({required String id, required int role}) => {
    'id': id,
    'role': role,
    'firstName': 'View',
    'lastName': 'Er',
  };

  Map<String, dynamic> profileJson(String role) => {
    'firstName': 'Actual',
    'lastName': 'Person',
    'role': role,
    'reviewCount': 0,
    'averageRating': 0,
    if (role == 'Tradie') 'tradeType': 'Plumber',
    if (role == 'Tradie') 'isAvailable': false,
  };

  Future<void> mountPublic(
    WidgetTester tester, {
    required bool isTradie,
    required Map<String, dynamic> viewerProfile,
    required Map<String, dynamic> targetJson,
    List<ConversationSummary> convs = const [],
    List<Job> jobs = const [],
    bool dark = false,
    JobsFixture? jobsFixture,
  }) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            ProfileFixture(viewerProfile),
          ),
          reviewsRepositoryProvider.overrideWithValue(
            ReviewsFixture(targetJson),
          ),
          chatRepositoryProvider.overrideWithValue(ChatFixture(convs)),
          jobsRepositoryProvider.overrideWithValue(
            jobsFixture ?? JobsFixture(jobs),
          ),
        ],
        child: MaterialApp(
          theme: dark ? FixoTheme.dark() : FixoTheme.light(),
          home: PublicProfileScreen(profileId: 'target', isTradie: isTradie),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ── Four role/ownership combinations ─────────────────────────────────────

  testWidgets('homeowner viewing tradie sees Request and Message', (
    tester,
  ) async {
    final jobs = JobsFixture([
      job('open-1', 'Requested', 'viewer', ''),
      job('closed', 'Completed', 'viewer', 'target'),
    ]);
    await mountPublic(
      tester,
      isTradie: true,
      viewerProfile: viewer(id: 'viewer', role: 0),
      targetJson: profileJson('Tradie'),
      convs: [
        conv('booked', 'Booked', 'target'),
        conv('done', 'Completed', 'other'),
      ],
      jobsFixture: jobs,
    );
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Request this tradie'), findsOneWidget);
    expect(find.text('Not taking jobs'), findsOneWidget);

    await tester.tap(find.text('Request this tradie'));
    await tester.pumpAndSettle();
    expect(jobs.requestedJobId, 'open-1');
    expect(jobs.requestedTradieId, 'target');
    expect(find.textContaining('Request sent'), findsOneWidget);
  });

  testWidgets('homeowner viewing tradie with no open job sees no Request', (
    tester,
  ) async {
    await mountPublic(
      tester,
      isTradie: true,
      viewerProfile: viewer(id: 'viewer', role: 0),
      targetJson: profileJson('Tradie'),
      convs: const [],
      jobs: [job('closed', 'Completed', 'viewer', 'target')],
    );
    expect(find.text('Request this tradie'), findsNothing);
    expect(find.text('Message'), findsNothing);
  });

  testWidgets('tradie viewing homeowner gets Message but no Request', (
    tester,
  ) async {
    await mountPublic(
      tester,
      isTradie: false,
      viewerProfile: viewer(id: 'viewer', role: 1),
      targetJson: profileJson('Homeowner'),
      convs: [conv('active', 'InProgress', 'target')],
      jobs: const [],
    );
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Request this tradie'), findsNothing);
    // Homeowner profiles never render the tradie-only Verified stat.
    expect(find.text('Verified'), findsNothing);
    expect(find.text('Available for jobs'), findsNothing);
    expect(find.text('Not taking jobs'), findsNothing);
  });

  testWidgets('closed shared conversation does not offer Message', (
    tester,
  ) async {
    await mountPublic(
      tester,
      isTradie: true,
      viewerProfile: viewer(id: 'viewer', role: 0),
      targetJson: profileJson('Tradie'),
      convs: [conv('done', 'Disputed', 'target')],
      jobs: const [],
    );
    expect(find.text('Message'), findsNothing);
  });

  testWidgets('owner viewing own profile: Edit only, no contextual actions', (
    tester,
  ) async {
    await mountPublic(
      tester,
      isTradie: true,
      viewerProfile: viewer(id: 'target', role: 1),
      targetJson: profileJson('Tradie'),
      convs: [conv('booked', 'Booked', 'target')],
      jobsFixture: JobsFixture([job('open-1', 'Requested', 'target', '')]),
    );
    await tester.scrollUntilVisible(
      find.text('Edit Profile'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Message'), findsNothing);
    expect(find.text('Request this tradie'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public tradie profile never shows payout fields', (
    tester,
  ) async {
    await mountPublic(
      tester,
      isTradie: true,
      viewerProfile: viewer(id: 'viewer', role: 0),
      targetJson: profileJson('Tradie'),
    );
    expect(find.text('Bank Account Number'), findsNothing);
    expect(find.text('Payout Details'), findsNothing);
  });

  // ── Self profile (ProfileScreen) ─────────────────────────────────────────

  Future<void> mountSelf(
    WidgetTester tester,
    ProfileFixture fixture, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(fixture)],
        child: MaterialApp(
          theme: dark ? FixoTheme.dark() : FixoTheme.light(),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets('tradie self profile shows payout section dark=$dark', (
      tester,
    ) async {
      final fixture = ProfileFixture({
        'id': 'me',
        'role': 1,
        'firstName': 'Jamie',
        'lastName': 'Builder',
        'email': 'j@x.nz',
        'isAvailable': true,
        'bankAccountName': 'Jamie Builder',
        'bankAccountNumber': '01-0234-0567890-12',
        'bankAccountVerified': true,
      });
      await mountSelf(tester, fixture, dark: dark);
      await tester.scrollUntilVisible(
        find.text('Bank Account Number'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Payout Details'), findsOneWidget);
      expect(find.text('Bank Account Name'), findsOneWidget);
      expect(
        find.text('Verified — used for your weekly payout.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('homeowner self profile hides tradie sections', (tester) async {
    await mountSelf(
      tester,
      ProfileFixture({
        'id': 'me',
        'role': 0,
        'firstName': 'Sam',
        'lastName': 'Home',
        'email': 's@x.nz',
      }),
    );
    expect(find.text('Tradie Information'), findsNothing);
    expect(find.text('Payout Details'), findsNothing);
    expect(find.text('Available for jobs'), findsNothing);
  });

  testWidgets('availability toggle saves immediately via endpoint', (
    tester,
  ) async {
    final fixture = ProfileFixture({
      'id': 'me',
      'role': 1,
      'firstName': 'Jamie',
      'lastName': 'Builder',
      'email': 'j@x.nz',
      'isAvailable': true,
    });
    await mountSelf(tester, fixture);
    await tester.scrollUntilVisible(
      find.text('Available for jobs'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Available for jobs'));
    await tester.pumpAndSettle();
    expect(fixture.availabilitySaved, false);
  });

  testWidgets('bank number validation enforces NZ format on save', (
    tester,
  ) async {
    final fixture = ProfileFixture({
      'id': 'me',
      'role': 1,
      'firstName': 'Jamie',
      'lastName': 'Builder',
      'email': 'j@x.nz',
      'isAvailable': true,
    });
    await mountSelf(tester, fixture);
    // Enter edit mode and type an invalid account number.
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Bank Account Number'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bank Account Number'),
      '12345',
    );
    await tester.scrollUntilVisible(
      find.text('Save Changes'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Format: XX-XXXX-XXXXXXX-XX'), findsOneWidget);
    expect(fixture.updatePayload, isNull);
  });

  testWidgets('valid bank details are included in the save payload', (
    tester,
  ) async {
    final fixture = ProfileFixture({
      'id': 'me',
      'role': 1,
      'firstName': 'Jamie',
      'lastName': 'Builder',
      'email': 'j@x.nz',
      'isAvailable': true,
    });
    await mountSelf(tester, fixture);
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Bank Account Name'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bank Account Name'),
      'Jamie Builder Ltd',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bank Account Number'),
      '12-3456-7890123-45',
    );
    await tester.scrollUntilVisible(
      find.text('Save Changes'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(fixture.updatePayload?['bankAccountName'], 'Jamie Builder Ltd');
    expect(fixture.updatePayload?['bankAccountNumber'], '12-3456-7890123-45');
  });

  // ── Settings ─────────────────────────────────────────────────────────────

  Future<void> mountSettings(
    WidgetTester tester, {
    required Map<String, dynamic> viewerProfile,
    bool dark = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            ProfileFixture(viewerProfile),
          ),
          localeConfigProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: dark ? FixoTheme.dark() : FixoTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets('settings rows meet the 48px target dark=$dark', (
      tester,
    ) async {
      await mountSettings(
        tester,
        viewerProfile: viewer(id: 'me', role: 0),
        dark: dark,
      );
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
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('theme row opens a picker sheet', (tester) async {
    await mountSettings(tester, viewerProfile: viewer(id: 'me', role: 0));
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    // The sheet options sit above the row subtitle, so use .last for each.
    expect(find.text('System'), findsNWidgets(2));
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget); // subtitle now reads Dark
  });

  testWidgets('payout row only appears for tradies', (tester) async {
    await mountSettings(tester, viewerProfile: viewer(id: 'me', role: 0));
    expect(find.text('Payout Details'), findsNothing);
  });

  testWidgets('tradie sees payout row under Account', (tester) async {
    await mountSettings(tester, viewerProfile: viewer(id: 'me', role: 1));
    expect(find.text('Payout Details'), findsOneWidget);
  });
}
