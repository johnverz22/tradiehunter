import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marketplace.dart';
import '../../repositories/chat_reviews_repository.dart';
import '../../viewmodels/jobs_viewmodel.dart';

/// Public profile + aggregated rating for the viewed tradie.
final thProfileProvider = FutureProvider.autoDispose
    .family<UserProfile?, String>(
      (ref, profileId) =>
          ref.watch(reviewsRepositoryProvider).getProfile(profileId),
    );

/// The viewed tradie's row on the job's Choose-a-Tradie list. Null when the
/// tradie is not listed for this job, so the job-scoped rate is omitted.
final thJobTradieProvider = FutureProvider.autoDispose
    .family<TradieListEntry?, (String, String)>((ref, ids) async {
      final (jobId, tradieId) = ids;
      final entries = await ref
          .watch(jobsRepositoryProvider)
          .getTradieList(jobId);
      for (final entry in entries) {
        if (entry.tradieId == tradieId) return entry;
      }
      return null;
    });

class ThReviewsState {
  const ThReviewsState({
    this.reviews = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 1,
    this.hasError = false,
  });

  final List<Review> reviews;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final bool hasError;

  ThReviewsState copyWith({
    List<Review>? reviews,
    bool? isLoading,
    bool? hasMore,
    int? page,
    bool? hasError,
  }) => ThReviewsState(
    reviews: reviews ?? this.reviews,
    isLoading: isLoading ?? this.isLoading,
    hasMore: hasMore ?? this.hasMore,
    page: page ?? this.page,
    hasError: hasError ?? this.hasError,
  );
}

class ThReviewsNotifier extends StateNotifier<ThReviewsState> {
  ThReviewsNotifier(this._repo, this._profileId)
    : super(const ThReviewsState());

  final ReviewsRepository _repo;
  final String _profileId;
  static const int _pageSize = 10;

  Future<void> loadNext() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, hasError: false);
    try {
      final result = await _repo.getReviewsForUser(
        _profileId,
        page: state.page,
        pageSize: _pageSize,
      );
      state = state.copyWith(
        reviews: [...state.reviews, ...result.items],
        isLoading: false,
        hasMore: result.hasMore,
        page: state.page + 1,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, hasError: true);
    }
  }
}

final thReviewsProvider = StateNotifierProvider.autoDispose
    .family<ThReviewsNotifier, ThReviewsState, String>((ref, profileId) {
      final notifier = ThReviewsNotifier(
        ref.read(reviewsRepositoryProvider),
        profileId,
      );
      notifier.loadNext();
      return notifier;
    });
