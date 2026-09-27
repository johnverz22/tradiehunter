import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/marketplace.dart';
import '../repositories/jobs_repository.dart';
import '../repositories/job_hub_client.dart';
import '../repositories/chat_reviews_repository.dart';
import 'auth_viewmodel.dart';

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(
      ref.watch(dioProvider), ref.watch(secureStorageProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
      ref.watch(dioProvider), ref.watch(secureStorageProvider));
});

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return ReviewsRepository(
      ref.watch(dioProvider), ref.watch(secureStorageProvider));
});

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(
      ref.watch(dioProvider), ref.watch(secureStorageProvider));
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
        stage = 1;
        break;
      case 'Confirmed':
      case 'InProgress':
        stage = 2;
        break;
      case 'Complete':
        stage = 3;
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
        );
      }
      return job;
    }).toList();
    
    state = state.copyWith(jobs: updatedJobs);
  }
}

final jobsViewModelProvider =
    StateNotifierProvider<JobsNotifier, JobsState>((ref) {
  return JobsNotifier(ref.watch(jobsRepositoryProvider));
});

// ── PostJobState ──────────────────────────────────────────────────────────────

/// Form state for the Post a Job screen (M2-07).
class PostJobState {
  final String category;
  final String description;
  final String urgency;
  final String address;
  final double? latitude;
  final double? longitude;
  final List<String> photoPaths;  // local file paths before upload
  final List<String> photoUrls;   // URLs returned by server after upload
  final bool isSubmitting;
  final String? error;
  final String? submittedJobId;

  const PostJobState({
    this.category = 'Plumbing',
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
  });

  bool get isValid =>
      category.isNotEmpty &&
      description.isNotEmpty;

  PostJobState copyWith({
    String? category,
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
  }) =>
      PostJobState(
        category: category ?? this.category,
        description: description ?? this.description,
        urgency: urgency ?? this.urgency,
        address: address ?? this.address,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        photoPaths: photoPaths ?? this.photoPaths,
        photoUrls: photoUrls ?? this.photoUrls,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: error,
        submittedJobId: submittedJobId ?? this.submittedJobId,
      );
}

class PostJobNotifier extends StateNotifier<PostJobState> {
  final JobsRepository _repo;
  PostJobNotifier(this._repo) : super(const PostJobState());

  void setCategory(String category) =>
      state = state.copyWith(category: category);

  void setDescription(String description) =>
      state = state.copyWith(description: description);

  void setUrgency(String urgency) =>
      state = state.copyWith(urgency: urgency);

  void setAddress(String address) =>
      state = state.copyWith(address: address);

  void setLocation({required double lat, required double lng}) =>
      state = state.copyWith(latitude: lat, longitude: lng);

  void addPhoto(String path) {
    if (state.photoPaths.length >= 5) return;
    state = state.copyWith(photoPaths: [...state.photoPaths, path]);
  }

  void removePhoto(String path) {
    state = state.copyWith(
        photoPaths: state.photoPaths.where((p) => p != path).toList());
  }

  /// Posts the job, then uploads any photos. Returns the new job ID string.
  Future<String?> submit() async {
    if (!state.isValid) {
      state = state.copyWith(error: 'Category and description are required.');
      return null;
    }
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final jobId = await _repo.postJob({
        'title': '${state.category} — ${state.description.substring(0, state.description.length.clamp(0, 60))}',
        'category': state.category,
        'description': state.description,
        'urgency': state.urgency,
        if (state.latitude != null) 'latitude': state.latitude,
        if (state.longitude != null) 'longitude': state.longitude,
        if (state.address.isNotEmpty) 'address': state.address,
      });

      // Upload photos if any were selected.
      if (state.photoPaths.isNotEmpty) {
        final urls = await _repo.uploadPhotos(jobId, state.photoPaths);
        state = state.copyWith(photoUrls: urls);
      }

      state = state.copyWith(isSubmitting: false, submittedJobId: jobId);
      return jobId;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return null;
    }
  }
}

final postJobProvider =
    StateNotifierProvider.autoDispose<PostJobNotifier, PostJobState>((ref) {
  return PostJobNotifier(ref.watch(jobsRepositoryProvider));
});
