import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../models/marketplace.dart';
import '../models/address.dart';
import '../repositories/profile_repository.dart';
import '../repositories/jobs_repository.dart';
import '../repositories/address_repository.dart';
import '../repositories/job_hub_client.dart';
import '../repositories/chat_reviews_repository.dart';
import 'auth_viewmodel.dart';
import 'address_viewmodel.dart' show addressRepositoryProvider;

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
  );
});

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return ReviewsRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
  );
});

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
  );
});

/// Singleton SignalR hub client. Lazily connected on first use.
final jobHubClientProvider = Provider<JobHubClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final client = JobHubClient(storage);
  ref.onDispose(client.dispose);
  return client;
});

// ── JobsState (homeowner/tradie list) ─────────────────────────────────────────

class JobsState {
  final bool isLoading;
  final String? error;
  final List<Job> jobs;

  const JobsState({this.isLoading = false, this.error, this.jobs = const []});

  JobsState copyWith({bool? isLoading, String? error, List<Job>? jobs}) =>
      JobsState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        jobs: jobs ?? this.jobs,
      );
}

class JobsNotifier extends StateNotifier<JobsState> {
  final JobsRepository _repo;
  JobsNotifier(this._repo) : super(const JobsState());

  Future<void> loadHomeownerJobs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final jobs = await _repo.getMyJobs();
      state = state.copyWith(isLoading: false, jobs: jobs);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadTradieJobs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final jobs = await _repo.getTradieJobs();
      state = state.copyWith(isLoading: false, jobs: jobs);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void applyStatusUpdate(String jobId, String status) {
    int stage = 0;
    switch (status) {
      case 'Requested':
      case 'Matching':
        stage = 0;
        break;
      case 'Matched':
      case 'AwaitingPayment':
      case 'PaymentReview':
        stage = 1;
        break;
      case 'Booked':
      case 'InProgress':
        stage = 2;
        break;
      case 'AwaitingConfirmation':
        stage = 3;
        break;
      case 'Completed':
        stage = 4;
        break;
    }

    final updatedJobs = state.jobs.map((job) {
      if (job.id.toString() == jobId) {
        return Job(
          id: job.id,
          title: job.title,
          category: job.category,
          suburb: job.suburb,
          status: status,
          stage: stage,
          urgency: job.urgency,
          description: job.description,
          photoUrls: job.photoUrls,
          createdAtUtc: job.createdAtUtc,
          address: job.address,
          latitude: job.latitude,
          longitude: job.longitude,
          matchedTradieId: job.matchedTradieId,
          serviceId: job.serviceId,
          scheduledStartUtc: job.scheduledStartUtc,
          hours: job.hours,
          hourlyRate: job.hourlyRate,
          totalAmount: job.totalAmount,
          referenceCode: job.referenceCode,
          disputeStatus: job.disputeStatus,
        );
      }
      return job;
    }).toList();

    state = state.copyWith(jobs: updatedJobs);
  }
}

final jobsViewModelProvider = StateNotifierProvider<JobsNotifier, JobsState>((
  ref,
) {
  return JobsNotifier(ref.watch(jobsRepositoryProvider));
});

// ── Matching progress (P3-09) ─────────────────────────────────────────────────

/// Where a job's sequential matching run has got to, as seen by the homeowner.
enum MatchingPhase {
  /// Nothing has happened yet — the match request is still being dispatched.
  starting,

  /// An offer is out and waiting on a tradie.
  contactingTradie,

  /// The matching run was cancelled because every candidate was exhausted.
  noTradieFound,

  /// A tradie accepted; the job has moved on to the matched state.
  matched,
}

/// State backing the homeowner's matching screen. Fed by SignalR
/// [OfferLifecycleEvent]s and [JobStatusEvent]s (P3-10) — the screen never
/// polls.
class MatchingProgressState {
  final String jobId;
  final MatchingPhase phase;

  /// 1-based index of the tradie currently being contacted, from the server's
  /// `offerIndex`. Zero until the first offer is created.
  final int offerIndex;

  /// How many offers have been dispatched so far in this run.
  final int offersMade;

  /// Set when the run ended without a match, for the empty state.
  final String? reason;

  const MatchingProgressState({
    required this.jobId,
    this.phase = MatchingPhase.starting,
    this.offerIndex = 0,
    this.offersMade = 0,
    this.reason,
  });

  /// Headline for the matching screen, e.g. "Contacting Tradie 2…".
  String get headline => switch (phase) {
    MatchingPhase.starting => 'Finding tradies near you…',
    MatchingPhase.contactingTradie =>
      offerIndex > 0
          ? 'Contacting Tradie $offerIndex…'
          : 'Contacting a tradie…',
    MatchingPhase.noTradieFound => 'No tradies available',
    MatchingPhase.matched => 'Tradie found',
  };

  /// Supporting line under the headline.
  String get subhead => switch (phase) {
    MatchingPhase.starting => 'Checking availability and distance',
    MatchingPhase.contactingTradie =>
      offersMade > 1
          ? '$offersMade tradies contacted — holding the best one'
          : 'We\'ll let you know as soon as they reply',
    MatchingPhase.noTradieFound =>
      reason ?? 'We couldn\'t find a match right now. Please try again later.',
    MatchingPhase.matched => 'Your tradie is booked in',
  };

  MatchingProgressState copyWith({
    MatchingPhase? phase,
    int? offerIndex,
    int? offersMade,
    String? reason,
  }) => MatchingProgressState(
    jobId: jobId,
    phase: phase ?? this.phase,
    offerIndex: offerIndex ?? this.offerIndex,
    offersMade: offersMade ?? this.offersMade,
    reason: reason ?? this.reason,
  );
}

/// Tracks one job's sequential matching run. Family-keyed by job id so two
/// concurrent matching screens cannot clobber each other.
class MatchingProgressNotifier extends StateNotifier<MatchingProgressState> {
  MatchingProgressNotifier(this._jobId)
    : super(MatchingProgressState(jobId: _jobId));

  final String _jobId;

  /// Seeds state from an existing pending offer discovered on screen entry.
  void seedFromOffer(JobOffer offer) {
    if (offer.jobId != _jobId) return;
    state = state.copyWith(
      phase: MatchingPhase.contactingTradie,
      offerIndex: state.offerIndex > 0 ? state.offerIndex : 1,
      offersMade: state.offersMade > 0 ? state.offersMade : 1,
      reason: null,
    );
  }

  /// Applies an offer lifecycle event. Ignores events for other jobs.
  void applyOfferEvent(OfferLifecycleEvent event) {
    if (event.jobId != _jobId) return;
    switch (event.eventType) {
      case OfferEventType.created:
        state = state.copyWith(
          phase: MatchingPhase.contactingTradie,
          offerIndex: event.offerIndex,
          offersMade: event.offerIndex > 0
              ? event.offerIndex
              : state.offersMade + 1,
          reason: null,
        );
      case OfferEventType.expired:
      case OfferEventType.declined:
        // The next offer (or the terminal cancel) arrives on a later event.
        state = state.copyWith(offersMade: state.offersMade + 1, reason: null);
      case OfferEventType.accepted:
        state = state.copyWith(phase: MatchingPhase.matched, reason: null);
      case OfferEventType.unknown:
        break;
    }
  }

  /// Applies a job status transition — the terminal `Cancelled` with
  /// `no_tradie_found` is what ends the run without a match.
  void applyStatusEvent(JobStatusEvent event) {
    if (event.jobId != _jobId) return;
    if (event.status == 'Cancelled') {
      final noTradie = event.reasonCode == 'no_tradie_found';
      state = state.copyWith(
        phase: noTradie ? MatchingPhase.noTradieFound : state.phase,
        reason: noTradie ? event.reason : state.reason,
      );
    } else if (event.status == 'AwaitingPayment' || event.status == 'Matched') {
      state = state.copyWith(phase: MatchingPhase.matched, reason: null);
    }
  }
}

final matchingProgressProvider = StateNotifierProvider.autoDispose
    .family<MatchingProgressNotifier, MatchingProgressState, String>(
      (ref, jobId) => MatchingProgressNotifier(jobId),
    );

// ── PostJobState ──────────────────────────────────────────────────────────────

/// Form state for the Post a Job screen (M2-07).
class PostJobState {
  final String category;
  final String title;
  final AddressCandidate? resolvedAddress;
  final String? addressAttribution;
  final String description;
  final String urgency;
  final String address;
  final double? latitude;
  final double? longitude;
  final List<String> photoPaths; // local file paths before upload
  final List<String> photoUrls; // URLs returned by server after upload
  final bool isSubmitting;
  final String? error;
  final String? submittedJobId;
  final List<ServiceOption> services;
  final ServiceOption? selectedService;
  final List<ServiceRateOption> rateOptions;
  final ServiceRateOption? selectedRate;
  final int hours;
  final DateTime? scheduledStartLocal;
  final bool isLoadingRates;
  final bool isLoadingServices;

  const PostJobState({
    this.category = 'Plumber',
    this.title = '',
    this.resolvedAddress,
    this.addressAttribution,
    this.description = '',
    this.urgency = 'Medium',
    this.address = '',
    this.latitude,
    this.longitude,
    this.photoPaths = const [],
    this.photoUrls = const [],
    this.isSubmitting = false,
    this.error,
    this.submittedJobId,
    this.services = const [],
    this.selectedService,
    this.rateOptions = const [],
    this.selectedRate,
    this.hours = 1,
    this.scheduledStartLocal,
    this.isLoadingRates = false,
    this.isLoadingServices = true,
  });

  bool get isValid =>
      title.trim().isNotEmpty &&
      title.length <= 200 &&
      description.trim().isNotEmpty &&
      description.length <= 2000 &&
      resolvedAddress != null &&
      latitude != null &&
      longitude != null &&
      selectedService != null &&
      selectedRate != null &&
      hours > 0 &&
      scheduledStartLocal != null;

  PostJobState copyWith({
    String? category,
    String? title,
    AddressCandidate? resolvedAddress,
    String? addressAttribution,
    bool clearLocation = false,
    String? description,
    String? urgency,
    String? address,
    double? latitude,
    double? longitude,
    List<String>? photoPaths,
    List<String>? photoUrls,
    bool? isSubmitting,
    String? error,
    String? submittedJobId,
    List<ServiceOption>? services,
    ServiceOption? selectedService,
    List<ServiceRateOption>? rateOptions,
    ServiceRateOption? selectedRate,
    bool clearSelectedRate = false,
    int? hours,
    DateTime? scheduledStartLocal,
    bool? isLoadingRates,
    bool? isLoadingServices,
  }) => PostJobState(
    category: category ?? this.category,
    title: title ?? this.title,
    resolvedAddress: clearLocation
        ? null
        : resolvedAddress ?? this.resolvedAddress,
    addressAttribution: clearLocation
        ? null
        : addressAttribution ?? this.addressAttribution,
    description: description ?? this.description,
    urgency: urgency ?? this.urgency,
    address: address ?? this.address,
    latitude: clearLocation ? null : latitude ?? this.latitude,
    longitude: clearLocation ? null : longitude ?? this.longitude,
    photoPaths: photoPaths ?? this.photoPaths,
    photoUrls: photoUrls ?? this.photoUrls,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    error: error,
    submittedJobId: submittedJobId ?? this.submittedJobId,
    services: services ?? this.services,
    selectedService: selectedService ?? this.selectedService,
    rateOptions: rateOptions ?? this.rateOptions,
    selectedRate: clearSelectedRate
        ? null
        : (selectedRate ?? this.selectedRate),
    hours: hours ?? this.hours,
    scheduledStartLocal: scheduledStartLocal ?? this.scheduledStartLocal,
    isLoadingRates: isLoadingRates ?? this.isLoadingRates,
    isLoadingServices: isLoadingServices ?? this.isLoadingServices,
  );
}

class PostJobNotifier extends StateNotifier<PostJobState> {
  final JobsRepository _repo;
  final AddressRepository? _addressRepo;
  int _rateGeneration = 0;
  PostJobNotifier(this._repo, [this._addressRepo]) : super(const PostJobState()) {
    loadServices();
    _loadCachedAddress();
  }

  Future<void> _loadCachedAddress() async {
    final cached = await _addressRepo?.loadCachedAddress();
    if (!mounted || cached == null) return;
    state = state.copyWith(
      address: cached.address,
      resolvedAddress: cached,
      // No attribution stored — it's not needed after selection.
      latitude: cached.latitude,
      longitude: cached.longitude,
    );
  }

  Future<void> loadServices() async {
    state = state.copyWith(isLoadingServices: true);
    try {
      final services = await _repo.getServiceCatalog();
      if (!mounted) return;
      state = state.copyWith(services: services, isLoadingServices: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingServices: false,
        error: 'Could not load services. Please try again.',
      );
    }
  }

  Future<void> selectService(ServiceOption service) async {
    state = state.copyWith(
      selectedService: service,
      category: service.category,
      rateOptions: const [],
      clearSelectedRate: true,
      isLoadingRates: true,
      error: null,
    );
    await searchRates();
  }

  Future<void> searchRates() async {
    final generation = ++_rateGeneration;
    final service = state.selectedService;
    if (service == null || state.latitude == null || state.longitude == null) {
      state = state.copyWith(isLoadingRates: false);
      return;
    }
    state = state.copyWith(isLoadingRates: true, clearSelectedRate: true);
    try {
      final rates = await _repo.searchServiceRates(
        serviceId: service.id,
        latitude: state.latitude!,
        longitude: state.longitude!,
      );
      if (!mounted || generation != _rateGeneration) return;
      state = state.copyWith(rateOptions: rates, isLoadingRates: false);
    } catch (_) {
      if (!mounted || generation != _rateGeneration) return;
      state = state.copyWith(
        isLoadingRates: false,
        error: 'Could not find available rates for this service.',
      );
    }
  }

  void selectRate(ServiceRateOption rate) {
    if (!state.rateOptions.contains(rate)) return;
    state = state.copyWith(selectedRate: rate, error: null);
  }

  void setTitle(String title) => state = state.copyWith(title: title);

  void setHours(String value) =>
      state = state.copyWith(hours: int.tryParse(value) ?? 0, error: null);

  void setScheduledStartLocal(DateTime value) =>
      state = state.copyWith(scheduledStartLocal: value, error: null);

  void setCategory(String category) =>
      state = state.copyWith(category: category);

  void setDescription(String description) =>
      state = state.copyWith(description: description);

  void setUrgency(String urgency) => state = state.copyWith(urgency: urgency);

  void setAddress(String address) {
    ++_rateGeneration;
    state = state.copyWith(
      address: address,
      clearLocation: true,
      rateOptions: const [],
      clearSelectedRate: true,
      isLoadingRates: false,
    );
  }

  Future<void> selectAddress(
    AddressCandidate address,
    String attribution,
  ) async {
    if (!address.latitude.isFinite ||
        !address.longitude.isFinite ||
        address.latitude.abs() > 90 ||
        address.longitude.abs() > 180) {
      return;
    }
    state = state.copyWith(
      address: address.address,
      resolvedAddress: address,
      addressAttribution: attribution,
      latitude: address.latitude,
      longitude: address.longitude,
      rateOptions: const [],
      clearSelectedRate: true,
    );
    if (_addressRepo != null) {
      unawaited(_addressRepo.cacheAddress(address));
    }
    await searchRates();
  }

  void addPhoto(String path) {
    if (state.photoPaths.length >= 5) return;
    state = state.copyWith(photoPaths: [...state.photoPaths, path]);
  }

  void removePhoto(String path) {
    state = state.copyWith(
      photoPaths: state.photoPaths.where((p) => p != path).toList(),
    );
  }

  /// Posts the job, then uploads any photos. Returns the new job ID string.
  Future<String?> submit() async {
    if (state.isSubmitting) return null;
    if (!state.isValid) {
      state = state.copyWith(
        error: 'Choose a service and an address result, add a title and description, then choose hours, rate and start time.',
      );
      return null;
    }
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final jobId =
          state.submittedJobId ??
          await _repo.postJob({
            'title': state.title.trim(),
            'description': state.description,
            'urgency': state.urgency,
            'serviceId': state.selectedService!.id,
            'scheduledStartUtc': state.scheduledStartLocal!
                .toUtc()
                .toIso8601String(),
            'hours': state.hours,
            // Decimal remains text on the wire so it is never rounded through double.
            'hourlyRate': state.selectedRate!.hourlyRate.toString(),
            if (state.latitude != null) 'latitude': state.latitude,
            if (state.longitude != null) 'longitude': state.longitude,
            if (state.address.isNotEmpty) 'address': state.address,
          });

      if (!mounted) return jobId;
      state = state.copyWith(submittedJobId: jobId);
      // Upload photos if any were selected.
      if (state.photoPaths.isNotEmpty) {
        final urls = await _repo.uploadPhotos(jobId, state.photoPaths);
        if (!mounted) return jobId;
        state = state.copyWith(photoUrls: urls);
      }

      state = state.copyWith(isSubmitting: false, submittedJobId: jobId);
      return jobId;
    } catch (e) {
      if (!mounted) return null;
      state = state.copyWith(
        isSubmitting: false,
        error: state.submittedJobId != null
            ? 'Your job was created, but photos could not be uploaded. Retry the upload without posting another job.'
            : e is ProfileApiException
            ? e.message
            : 'Could not post your job. Please try again.',
      );
      return null;
    }
  }
}

final postJobProvider =
    StateNotifierProvider.autoDispose<PostJobNotifier, PostJobState>((ref) {
      return PostJobNotifier(
        ref.watch(jobsRepositoryProvider),
        ref.watch(addressRepositoryProvider),
      );
    });
