import 'package:decimal/decimal.dart';
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

// Re-exported so screens that talk to JobsRepository can catch its
// exception type with a single import (mirrors auth_viewmodel.dart).
export '../repositories/profile_repository.dart' show ProfileApiException;

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

  /// Applies a live status transition to one job in the list. The stage is
  /// recomputed under the job's own flow version (v1 keeps the legacy
  /// mapping, v2 uses the v1.7 stepper order — contract #6).
  void applyStatusUpdate(String jobId, String status) {
    final updatedJobs = state.jobs.map((job) {
      if (job.id.toString() == jobId) {
        return job.copyWith(
          status: status,
          stage: Job.stageForStatus(status, flowVersion: job.flowVersion),
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

/// v1.7 timing selector options (contract #1). The wire value is sent
/// verbatim as `timingPreference`.
const postJobTimingOptions = <(String, String, String)>[
  // (wire value, label, helper copy)
  ('Flexible', 'Flexible', 'Any time that suits the tradie\'s schedule'),
  ('Asap', 'ASAP', 'As soon as a tradie can get here'),
  ('SpecificDate', 'Pick a date', 'Choose a start date and time'),
  ('DateRange', 'Date range', 'Choose a start and end window'),
];

/// v1.7 project materials-responsibility options (contract #1).
const postJobMaterialsOptions = <(String, String)>[
  ('Tradie', 'Tradie buys'),
  ('Homeowner', 'I buy'),
  ('Undecided', 'Undecided'),
];

/// Form state for the Post a Job screen (M2-07, simplified in v1.7 P12-04).
///
/// v1.7: no tradie or rate picking on this screen — the homeowner describes
/// the job, picks timing (default Flexible) and optionally estimates hours.
/// Project jobs (P12-21/P12-22) add the optional budget / materials /
/// site-visit / scope-notes section. `hourlyRate` is never sent — rates are
/// snapshotted server-side when a tradie accepts.
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
  final bool isLoadingServices;

  /// Quick job (Hourly) | Project — segmented control at the top (P12-22).
  final String jobType;

  /// Flexible | Asap | SpecificDate | DateRange (contract #1).
  final String timingPreference;

  /// Local start — used for SpecificDate and DateRange.
  final DateTime? scheduledStartLocal;

  /// Local end — DateRange only.
  final DateTime? scheduledEndLocal;

  /// Optional; null means "skip if unsure".
  final double? estimatedHours;

  // ── Project-only optional fields ─────────────────────────────────────────
  final Decimal? budgetMin;
  final Decimal? budgetMax;
  final String materialsBy; // Tradie | Homeowner | Undecided
  final bool siteVisitWelcome;
  final String scopeNotes;

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
    this.isLoadingServices = true,
    this.jobType = Job.jobTypeHourly,
    this.timingPreference = 'Flexible',
    this.scheduledStartLocal,
    this.scheduledEndLocal,
    this.estimatedHours,
    this.budgetMin,
    this.budgetMax,
    this.materialsBy = 'Undecided',
    this.siteVisitWelcome = false,
    this.scopeNotes = '',
  });

  bool get isProject => jobType == Job.jobTypeProject;

  /// Timing state that backs the picker UI: SpecificDate needs a start,
  /// DateRange needs both ends.
  bool get timingComplete => switch (timingPreference) {
    'SpecificDate' => scheduledStartLocal != null,
    'DateRange' => scheduledStartLocal != null && scheduledEndLocal != null,
    _ => true,
  };

  bool get isValid =>
      title.trim().isNotEmpty &&
      title.length <= 200 &&
      description.trim().isNotEmpty &&
      description.length <= 2000 &&
      resolvedAddress != null &&
      latitude != null &&
      longitude != null &&
      selectedService != null &&
      timingComplete;

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
    bool? isLoadingServices,
    String? jobType,
    String? timingPreference,
    DateTime? scheduledStartLocal,
    bool clearScheduledStart = false,
    DateTime? scheduledEndLocal,
    bool clearScheduledEnd = false,
    double? estimatedHours,
    bool clearEstimatedHours = false,
    Decimal? budgetMin,
    bool clearBudgetMin = false,
    Decimal? budgetMax,
    bool clearBudgetMax = false,
    String? materialsBy,
    bool? siteVisitWelcome,
    String? scopeNotes,
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
    isLoadingServices: isLoadingServices ?? this.isLoadingServices,
    jobType: jobType ?? this.jobType,
    timingPreference: timingPreference ?? this.timingPreference,
    scheduledStartLocal: clearScheduledStart
        ? null
        : scheduledStartLocal ?? this.scheduledStartLocal,
    scheduledEndLocal: clearScheduledEnd
        ? null
        : scheduledEndLocal ?? this.scheduledEndLocal,
    estimatedHours: clearEstimatedHours
        ? null
        : estimatedHours ?? this.estimatedHours,
    budgetMin: clearBudgetMin ? null : budgetMin ?? this.budgetMin,
    budgetMax: clearBudgetMax ? null : budgetMax ?? this.budgetMax,
    materialsBy: materialsBy ?? this.materialsBy,
    siteVisitWelcome: siteVisitWelcome ?? this.siteVisitWelcome,
    scopeNotes: scopeNotes ?? this.scopeNotes,
  );
}

class PostJobNotifier extends StateNotifier<PostJobState> {
  final JobsRepository _repo;
  final AddressRepository? _addressRepo;
  PostJobNotifier(this._repo, [this._addressRepo])
    : super(const PostJobState()) {
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

  /// v1.7: selecting a service no longer searches nearby rates — pricing
  /// happens when a tradie is chosen or quotes come back.
  Future<void> selectService(ServiceOption service) async {
    state = state.copyWith(
      selectedService: service,
      category: service.category,
      error: null,
    );
  }

  void setJobType(String jobType) {
    // Switching type never loses shared input (P12-22) — only the timing
    // selection is meaningful for both, and it stays untouched.
    state = state.copyWith(jobType: jobType, error: null);
  }

  void setTimingPreference(String value) {
    final keepsDates = value == 'SpecificDate' || value == 'DateRange';
    state = state.copyWith(
      timingPreference: value,
      // Dropping back to Flexible/ASAP clears any picked dates so the
      // payload never sends stale schedule fields.
      clearScheduledStart: !keepsDates,
      clearScheduledEnd: !keepsDates,
      error: null,
    );
  }

  void setTitle(String title) => state = state.copyWith(title: title);

  /// Accepts "2", "2.5" etc.; empty/invalid clears the optional estimate.
  void setEstimatedHours(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    final valid = parsed != null && parsed > 0;
    state = state.copyWith(
      estimatedHours: valid ? parsed : null,
      clearEstimatedHours: !valid,
      error: null,
    );
  }

  void setScheduledStartLocal(DateTime value) =>
      state = state.copyWith(scheduledStartLocal: value, error: null);

  void setScheduledEndLocal(DateTime value) =>
      state = state.copyWith(scheduledEndLocal: value, error: null);

  void setBudgetMin(String value) {
    final parsed = Decimal.tryParse(value.trim());
    state = state.copyWith(
      budgetMin: parsed,
      clearBudgetMin: parsed == null,
      error: null,
    );
  }

  void setBudgetMax(String value) {
    final parsed = Decimal.tryParse(value.trim());
    state = state.copyWith(
      budgetMax: parsed,
      clearBudgetMax: parsed == null,
      error: null,
    );
  }

  void setMaterialsBy(String value) =>
      state = state.copyWith(materialsBy: value);

  void setSiteVisitWelcome(bool value) =>
      state = state.copyWith(siteVisitWelcome: value);

  void setScopeNotes(String value) => state = state.copyWith(scopeNotes: value);

  void setCategory(String category) =>
      state = state.copyWith(category: category);

  void setDescription(String description) =>
      state = state.copyWith(description: description);

  void setUrgency(String urgency) => state = state.copyWith(urgency: urgency);

  void setAddress(String address) {
    state = state.copyWith(address: address, clearLocation: true, error: null);
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
    );
    if (_addressRepo != null) {
      unawaited(_addressRepo.cacheAddress(address));
    }
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

  /// Posts the job (contract #1), then uploads any photos. Returns the new
  /// job ID string. `hourlyRate` is deliberately never sent — the wire field
  /// is ignored by the v1.7 backend and rates are snapshotted at acceptance.
  Future<String?> submit() async {
    if (state.isSubmitting) return null;
    if (!state.isValid) {
      state = state.copyWith(
        error:
            'Choose a service and an address result, add a title and '
            'description, then complete the timing selection.',
      );
      return null;
    }
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final payload = <String, dynamic>{
        'title': state.title.trim(),
        'description': state.description,
        'urgency': state.urgency,
        if (state.latitude != null) 'latitude': state.latitude,
        if (state.longitude != null) 'longitude': state.longitude,
        if (state.address.isNotEmpty) 'address': state.address,
        'serviceId': state.selectedService!.id,
        'timingPreference': state.timingPreference,
        // Only the date-backed preferences send schedule fields (UTC ISO8601).
        if (state.timingPreference == 'SpecificDate' ||
            state.timingPreference == 'DateRange')
          if (state.scheduledStartLocal != null)
            'scheduledStartUtc': state.scheduledStartLocal!
                .toUtc()
                .toIso8601String(),
        if (state.timingPreference == 'DateRange' &&
            state.scheduledEndLocal != null)
          'scheduledEndUtc': state.scheduledEndLocal!.toUtc().toIso8601String(),
        if (state.estimatedHours != null)
          'estimatedHours': state.estimatedHours,
        'jobType': state.jobType,
        if (state.isProject) ...{
          // Money stays text on the wire so it is never rounded through double.
          if (state.budgetMin != null) 'budgetMin': state.budgetMin.toString(),
          if (state.budgetMax != null) 'budgetMax': state.budgetMax.toString(),
          'materialsBy': state.materialsBy,
          'siteVisitWelcome': state.siteVisitWelcome,
          if (state.scopeNotes.trim().isNotEmpty)
            'scopeNotes': state.scopeNotes.trim(),
        },
      };

      final jobId = state.submittedJobId ?? await _repo.postJob(payload);

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

// ── Choose-a-Tradie list (v1.7 P12-05 / P12-06) ───────────────────────────────

/// Sort options for GET /api/jobs/:id/tradies — wire values per contract #2.
enum TradieListSort {
  best('Best match'),
  rating('Top rated'),
  distance('Nearest'),
  rate('Lowest rate');

  const TradieListSort(this.label);
  final String label;
}

class TradieListState {
  final bool isLoading;
  final String? error;
  final List<TradieListEntry> tradies;
  final TradieListSort sort;
  final bool verifiedOnly;
  final bool insuredOnly;
  final bool availableNowOnly;

  const TradieListState({
    this.isLoading = false,
    this.error,
    this.tradies = const [],
    this.sort = TradieListSort.best,
    this.verifiedOnly = false,
    this.insuredOnly = false,
    this.availableNowOnly = false,
  });

  TradieListState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<TradieListEntry>? tradies,
    TradieListSort? sort,
    bool? verifiedOnly,
    bool? insuredOnly,
    bool? availableNowOnly,
  }) => TradieListState(
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : error ?? this.error,
    tradies: tradies ?? this.tradies,
    sort: sort ?? this.sort,
    verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    insuredOnly: insuredOnly ?? this.insuredOnly,
    availableNowOnly: availableNowOnly ?? this.availableNowOnly,
  );
}

/// Loads the server-ranked tradie list for one job. Family-keyed by job id;
/// sort/filter changes re-fetch from the API (the server owns ranking).
class TradieListNotifier extends StateNotifier<TradieListState> {
  TradieListNotifier(this._repo, this._jobId) : super(const TradieListState());

  final JobsRepository _repo;
  final String _jobId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final tradies = await _repo.getTradieList(
        _jobId,
        sort: state.sort.name,
        verified: state.verifiedOnly,
        insured: state.insuredOnly,
        availableNow: state.availableNowOnly,
      );
      if (!mounted) return;
      state = state.copyWith(isLoading: false, tradies: tradies);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setSort(TradieListSort sort) async {
    if (sort == state.sort) return;
    state = state.copyWith(sort: sort);
    await load();
  }

  Future<void> toggleVerified() async {
    state = state.copyWith(verifiedOnly: !state.verifiedOnly);
    await load();
  }

  Future<void> toggleInsured() async {
    state = state.copyWith(insuredOnly: !state.insuredOnly);
    await load();
  }

  Future<void> toggleAvailableNow() async {
    state = state.copyWith(availableNowOnly: !state.availableNowOnly);
    await load();
  }
}

final tradieListProvider = StateNotifierProvider.autoDispose
    .family<TradieListNotifier, TradieListState, String>((ref, jobId) {
      final notifier = TradieListNotifier(
        ref.watch(jobsRepositoryProvider),
        jobId,
      );
      notifier.load();
      return notifier;
    });

// ── Quotes (v1.7 P12-23 / P12-24) ─────────────────────────────────────────────

/// State backing the homeowner quote-comparison screen and the tradie
/// quote form. Family-keyed by job id so two jobs never share state.
class QuotesState {
  final bool isLoading;

  /// Set when the initial load failed outright (network/server).
  final String? error;

  final List<Quote> quotes;

  /// Quote id currently being accepted — drives the per-card loading state.
  final String? acceptingQuoteId;

  /// Quote id currently being submitted (tradie side) or null.
  final bool isSubmitting;

  const QuotesState({
    this.isLoading = false,
    this.error,
    this.quotes = const [],
    this.acceptingQuoteId,
    this.isSubmitting = false,
  });

  QuotesState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<Quote>? quotes,
    String? acceptingQuoteId,
    bool clearAcceptingQuoteId = false,
    bool? isSubmitting,
  }) => QuotesState(
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    quotes: quotes ?? this.quotes,
    acceptingQuoteId: clearAcceptingQuoteId
        ? null
        : acceptingQuoteId ?? this.acceptingQuoteId,
    isSubmitting: isSubmitting ?? this.isSubmitting,
  );
}

class QuotesNotifier extends StateNotifier<QuotesState> {
  QuotesNotifier(this._repo, this._jobId) : super(const QuotesState());

  final JobsRepository _repo;
  final String _jobId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final quotes = await _repo.getQuotes(_jobId);
      if (!mounted) return;
      state = state.copyWith(isLoading: false, quotes: quotes);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Accepts [quoteId] (contract #13). Returns the repository's own
  /// [QuoteAcceptResult] — a `requiresWrittenContract` outcome means the
  /// caller must show the s362F notice and retry with
  /// `confirmWrittenContract: true`. Failures carry the server's message.
  Future<QuoteAcceptResult> acceptQuote(
    String quoteId, {
    required bool confirmWrittenContract,
  }) async {
    if (state.acceptingQuoteId != null) {
      return const QuoteAcceptResult.failure(
        'An acceptance is already in progress.',
      );
    }
    state = state.copyWith(acceptingQuoteId: quoteId, clearError: true);
    try {
      final result = await _repo.acceptQuote(
        _jobId,
        quoteId,
        confirmWrittenContract: confirmWrittenContract,
      );
      // A successful accept books the job — refresh so the accepted quote
      // reflects the server's own status.
      if (result.accepted && mounted) await load();
      return result;
    } finally {
      if (mounted) {
        state = state.copyWith(clearAcceptingQuoteId: true);
      }
    }
  }

  /// Tradie submits a quote (contract #12). Throws [ProfileApiException]
  /// with the server's message on failure — the form surfaces it verbatim.
  Future<void> submitQuote(Map<String, dynamic> payload) async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.createQuote(_jobId, payload);
    } finally {
      if (mounted) state = state.copyWith(isSubmitting: false);
    }
  }
}

final quotesProvider = StateNotifierProvider.autoDispose
    .family<QuotesNotifier, QuotesState, String>((ref, jobId) {
      final notifier = QuotesNotifier(ref.watch(jobsRepositoryProvider), jobId);
      notifier.load();
      return notifier;
    });
