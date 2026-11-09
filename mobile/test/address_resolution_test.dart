import 'dart:async';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:fixo/models/address.dart';
import 'package:fixo/models/marketplace.dart';
import 'package:fixo/repositories/address_repository.dart';
import 'package:fixo/repositories/jobs_repository.dart';
import 'package:fixo/repositories/profile_repository.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/viewmodels/address_viewmodel.dart';
import 'package:fixo/viewmodels/jobs_viewmodel.dart';
import 'package:fixo/viewmodels/profile_viewmodel.dart';
import 'package:fixo/views/jobs/post_job_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const selectedAddress = AddressCandidate(
  id: 'linz:123113:1',
  address: '1 Fixture Road, Auckland',
  latitude: -36.85,
  longitude: 174.76,
);
const service = ServiceOption(id: 1, name: 'Plumbing', category: 'Plumber');
final rate = ServiceRateOption(
  tradieId: 'tradie',
  name: 'Fixture tradie',
  hourlyRate: Decimal.parse('123.45'),
  distanceKm: 1.2,
);
const results = AddressSearchResult(
  provider: 'Linz',
  attribution: 'LINZ · CC BY 4.0',
  attributionUrl: 'https://data.linz.govt.nz/',
  items: [selectedAddress],
);

class AddressFixture extends AddressRepository {
  Future<AddressSearchResult> Function(String)? respond;
  final queries = <String>[];
  AddressFixture() : super(Dio(), const FlutterSecureStorage());
  @override
  Future<AddressSearchResult> search(String query) async {
    queries.add(query);
    return respond == null ? results : await respond!(query);
  }
}

class PostFixture extends JobsRepository {
  Future<List<ServiceRateOption>> Function()? rates;
  Map<String, dynamic>? posted;
  int posts = 0;
  bool failUpload = false;
  bool failPost = false;
  PostFixture() : super(Dio(), const FlutterSecureStorage());
  @override
  Future<List<ServiceOption>> getServiceCatalog() async => [service];
  @override
  Future<List<ServiceRateOption>> searchServiceRates({
    required int serviceId,
    required double latitude,
    required double longitude,
  }) async => rates == null ? [rate] : await rates!();
  @override
  Future<String> postJob(Map<String, dynamic> data) async {
    posts++;
    if (failPost) throw const ProfileApiException('Please sign in again.');
    posted = data;
    return '123';
  }

  @override
  Future<List<String>> uploadPhotos(
    String jobId,
    List<String> filePaths,
  ) async {
    if (failUpload) throw StateError('private transport detail');
    return ['photo'];
  }
}

class ProfileFixture extends ProfileRepository {
  ProfileFixture() : super(Dio(), const FlutterSecureStorage());
  @override
  Future<Map<String, dynamic>> getCurrentProfile() async => {
    'id': 'owner',
    'role': 0,
  };
}

Future<void> fill(PostJobNotifier notifier) async {
  await notifier.selectService(service);
  await notifier.selectAddress(selectedAddress, results.attribution);
  notifier.selectRate(rate);
  notifier.setTitle('Fix the tap');
  notifier.setDescription('The tap is leaking.');
  notifier.setHours('2');
  notifier.setScheduledStartLocal(DateTime(2027, 1, 5, 10));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('address parser rejects invalid coordinates and missing identity', () {
    final json = <String, dynamic>{
      'id': 'a',
      'address': 'Address',
      'latitude': -36.85,
      'longitude': 174.76,
    };
    expect(AddressCandidate.fromJson(json).longitude, 174.76);
    expect(
      () => AddressCandidate.fromJson({...json, 'latitude': double.nan}),
      throwsFormatException,
    );
    expect(
      () => AddressCandidate.fromJson({...json, 'longitude': 181}),
      throwsFormatException,
    );
    expect(
      () => AddressCandidate.fromJson({...json, 'id': ''}),
      throwsFormatException,
    );
  });

  testWidgets('address search debounces and ignores late responses', (
    tester,
  ) async {
    final repo = AddressFixture();
    final old = Completer<AddressSearchResult>();
    repo.respond = (query) =>
        query == 'Old road' ? old.future : Future.value(results);
    final notifier = AddressSearchNotifier(repo);
    addTearDown(notifier.dispose);
    notifier.edit('Old road');
    await tester.pump(const Duration(milliseconds: 400));
    notifier.edit('New');
    notifier.edit('New road');
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifier.state.result, results);
    old.complete(
      const AddressSearchResult(
        provider: 'Old',
        attribution: '',
        attributionUrl: '',
        items: [],
      ),
    );
    await tester.pump();
    expect(notifier.state.result, results);
    expect(repo.queries, ['Old road', 'New road']);
  });

  testWidgets('clearing or disposing invalidates pending searches', (
    tester,
  ) async {
    final repo = AddressFixture();
    final pending = Completer<AddressSearchResult>();
    repo.respond = (_) => pending.future;
    final notifier = AddressSearchNotifier(repo);
    notifier.edit('Fixture road');
    await tester.pump(const Duration(milliseconds: 400));
    notifier.clear();
    pending.complete(results);
    await tester.pump();
    expect(notifier.state.result, isNull);
    notifier.edit('Fixture road');
    notifier.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(repo.queries.length, 1);
  });

  testWidgets('search errors are truthful, retryable and distinct from empty', (
    tester,
  ) async {
    final repo = AddressFixture();
    repo.respond = (_) async =>
        throw const ProfileApiException('Address search unavailable');
    final notifier = AddressSearchNotifier(repo);
    addTearDown(notifier.dispose);
    notifier.edit('Fixture road');
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifier.state.error, 'Address search unavailable');
    expect(notifier.state.searched, isFalse);
    repo.respond = (_) async => const AddressSearchResult(
      provider: 'Linz',
      attribution: 'LINZ',
      attributionUrl: '',
      items: [],
    );
    await notifier.retry();
    expect(notifier.state.error, isNull);
    expect(notifier.state.searched, isTrue);
    expect(notifier.state.result!.items, isEmpty);
  });

  testWidgets('short and overlong searches never call provider', (
    tester,
  ) async {
    final repo = AddressFixture();
    final notifier = AddressSearchNotifier(repo);
    addTearDown(notifier.dispose);
    notifier.edit('ab');
    await tester.pump(const Duration(seconds: 1));
    notifier.edit('x' * 161);
    await tester.pump(const Duration(seconds: 1));
    expect(repo.queries, isEmpty);
    expect(notifier.state.error, isNotNull);
  });

  test('address edit clears coordinates, selection and stale rates', () async {
    final repo = PostFixture();
    final notifier = PostJobNotifier(repo);
    addTearDown(notifier.dispose);
    await fill(notifier);
    expect(notifier.state.isValid, isTrue);
    notifier.setAddress('A different address');
    expect(notifier.state.latitude, isNull);
    expect(notifier.state.longitude, isNull);
    expect(notifier.state.resolvedAddress, isNull);
    expect(notifier.state.selectedRate, isNull);
    expect(notifier.state.rateOptions, isEmpty);
    expect(await notifier.submit(), isNull);
    expect(repo.posts, 0);
  });

  test(
    'late rates cannot restore an edited address or changed service',
    () async {
      final repo = PostFixture();
      final pending = Completer<List<ServiceRateOption>>();
      repo.rates = () => pending.future;
      final notifier = PostJobNotifier(repo);
      addTearDown(notifier.dispose);
      await notifier.selectService(service);
      final request = notifier.selectAddress(selectedAddress, 'LINZ');
      notifier.setAddress('Edited');
      pending.complete([rate]);
      await request;
      expect(notifier.state.rateOptions, isEmpty);
      expect(notifier.state.isLoadingRates, isFalse);
    },
  );

  test(
    'submission preserves explicit title, Decimal pricing and UTC schedule',
    () async {
      final repo = PostFixture();
      final notifier = PostJobNotifier(repo);
      addTearDown(notifier.dispose);
      await fill(notifier);
      expect(await notifier.submit(), '123');
      expect(repo.posted!['title'], 'Fix the tap');
      expect(repo.posted!['hourlyRate'], '123.45');
      expect(repo.posted!['hours'], 2);
      expect(repo.posted!['latitude'], -36.85);
      expect(DateTime.parse(repo.posted!['scheduledStartUtc']).isUtc, isTrue);
    },
  );

  test(
    'photo failure retries the created job rather than posting twice',
    () async {
      final repo = PostFixture()..failUpload = true;
      final notifier = PostJobNotifier(repo);
      addTearDown(notifier.dispose);
      await fill(notifier);
      notifier.addPhoto('fixture-image');
      expect(await notifier.submit(), isNull);
      expect(notifier.state.submittedJobId, '123');
      expect(notifier.state.error, contains('Your job was created'));
      expect(notifier.state.error, isNot(contains('private transport detail')));
      repo.failUpload = false;
      expect(await notifier.submit(), '123');
      expect(repo.posts, 1);
    },
  );

  test('missing service, title, address and hours do not post', () async {
    final repo = PostFixture();
    final notifier = PostJobNotifier(repo);
    addTearDown(notifier.dispose);
    expect(await notifier.submit(), isNull);
    await fill(notifier);
    notifier.setTitle('   ');
    expect(await notifier.submit(), isNull);
    notifier.setTitle('Title');
    notifier.setHours('0');
    expect(await notifier.submit(), isNull);
    expect(repo.posts, 0);
  });

  test('photo retry reconciles a committed upload after a lost response and sets image MIME', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'fixture-token'});
    final directory = await Directory.systemTemp.createTemp('fixo-photo-test');
    addTearDown(() => directory.delete(recursive: true));
    final file = await File.fromUri(directory.uri.resolve('image'))
        .writeAsBytes([255, 216, 255, ...List.filled(32, 0)]);
    final dio = Dio();
    final stored = <Map<String, dynamic>>[];
    var posts = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.method == 'GET') {
            handler.resolve(
              Response(requestOptions: request, data: {'photos': stored}),
            );
          } else {
            posts++;
            final multipart = (request.data as FormData).files.single.value;
            expect(multipart.contentType.toString(), 'image/jpeg');
            stored.add({
              'originalFileName': multipart.filename,
              'url': 'uploaded-photo',
            });
            handler.reject(
              DioException.connectionTimeout(
                requestOptions: request,
                timeout: const Duration(seconds: 1),
              ),
            );
          }
        },
      ),
    );
    final repo = JobsRepository(dio, const FlutterSecureStorage());
    await expectLater(
      repo.uploadPhotos('123', [file.path]),
      throwsA(isA<DioException>()),
    );
    expect(await repo.uploadPhotos('123', [file.path]), ['uploaded-photo']);
    expect(posts, 1);
  });

  test('address repository uses our authenticated API and rejects malformed results', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'fixture-token'});
    final dio = Dio();
    var malformed = false;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          expect(request.path, '/api/addresses/search');
          expect(request.headers['Authorization'], 'Bearer fixture-token');
          expect(request.queryParameters, {'query': 'Fixture'});
          handler.resolve(
            Response(
              requestOptions: request,
              data: malformed
                  ? {'items': null}
                  : {
                      'provider': 'AnotherProvider',
                      'attribution': 'Required attribution',
                      'attributionUrl': '',
                      'items': [
                        {
                          'id': 'other:1',
                          'address': 'Fixture',
                          'latitude': -36.8,
                          'longitude': 174.7,
                        },
                      ],
                    },
            ),
          );
        },
      ),
    );
    final repository = AddressRepository(dio, const FlutterSecureStorage());
    expect((await repository.search('Fixture')).provider, 'AnotherProvider');
    malformed = true;
    await expectLater(
      repository.search('Fixture'),
      throwsA(isA<ProfileApiException>()),
    );
  });

  Future<void> mount(
    WidgetTester tester,
    PostFixture repo,
    AddressFixture addresses, {
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsRepositoryProvider.overrideWithValue(repo),
          addressRepositoryProvider.overrideWithValue(addresses),
          profileRepositoryProvider.overrideWithValue(ProfileFixture()),
        ],
        child: MaterialApp(
          theme: dark ? FixoTheme.dark() : FixoTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const PostJobScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'post form has hidden coordinates, selectable addresses and no overflow dark=$dark scale=$scale',
        (tester) async {
          await mount(
            tester,
            PostFixture(),
            AddressFixture(),
            dark: dark,
            scale: scale,
          );
          expect(find.byKey(const Key('latitude_field')), findsNothing);
          expect(find.byKey(const Key('longitude_field')), findsNothing);
          await tester.enterText(
            find.byKey(const Key('address_search_field')),
            '1 Fixture',
          );
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          expect(find.text(selectedAddress.address), findsOneWidget);
          await tester.ensureVisible(find.text(selectedAddress.address));
          await tester.tap(find.text(selectedAddress.address));
          await tester.pumpAndSettle();
          expect(find.text('Address selected'), findsOneWidget);
          await tester.ensureVisible(find.text('Review your job'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.byKey(const Key('address_search_field')),
          );
          await tester.enterText(
            find.byKey(const Key('address_search_field')),
            'Edited',
          );
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          expect(find.text('Address selected'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('provider failure offers retry without empty-success copy', (
    tester,
  ) async {
    final addresses = AddressFixture()
      ..respond = (_) async =>
          throw const ProfileApiException('Address search unavailable');
    await mount(tester, PostFixture(), addresses);
    await tester.enterText(
      find.byKey(const Key('address_search_field')),
      '1 Fixture',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Address search unavailable'), findsOneWidget);
    expect(find.textContaining('No matching addresses'), findsNothing);
    addresses.respond = null;
    await tester.ensureVisible(find.text('Retry address search'));
    await tester.tap(find.text('Retry address search'));
    await tester.pumpAndSettle();
    expect(find.text(selectedAddress.address), findsOneWidget);
  });
}
