import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/marketplace.dart';
import '../../repositories/chat_reviews_repository.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../widgets/rating_sheet.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Fetches public profile (with aggregated rating) for a given userId.
final _profileProvider =
    FutureProvider.family<UserProfile?, String>((ref, userId) async {
  final repo = ref.read(reviewsRepositoryProvider);
  return repo.getProfile(userId);
});

/// Paginated reviews state for a user.
class _ReviewsState {
  final List<Review> reviews;
  final bool isLoading;
  final bool hasMore;
  final int page;

  const _ReviewsState({
    this.reviews = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 1,
  });

  _ReviewsState copyWith({
    List<Review>? reviews,
    bool? isLoading,
    bool? hasMore,
    int? page,
  }) =>
      _ReviewsState(
        reviews: reviews ?? this.reviews,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
      );
}

class _ReviewsNotifier extends StateNotifier<_ReviewsState> {
  final ReviewsRepository _repo;
  final String _userId;
  static const _pageSize = 10;

  _ReviewsNotifier(this._repo, this._userId) : super(const _ReviewsState());

  Future<void> loadNext() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repo.getReviewsForUser(
        _userId,
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
      state = state.copyWith(isLoading: false, hasMore: false);
    }
  }
}

final _reviewsNotifierProvider = StateNotifierProvider.autoDispose
    .family<_ReviewsNotifier, _ReviewsState, String>((ref, userId) {
  final repo = ref.read(reviewsRepositoryProvider);
  final notifier = _ReviewsNotifier(repo, userId);
  notifier.loadNext(); // initial load
  return notifier;
});

// ── Screen ────────────────────────────────────────────────────────────────────

/// Shared public-profile header + stats + reviews.
/// Powers mockups 12-profile (tradie) and 15-homeowner-profile.
/// [isTradie] switches stat copy and enables tradie-specific fields.
class PublicProfileScreen extends ConsumerWidget {
  final String profileId;
  final bool isTradie;

  const PublicProfileScreen({
    super.key,
    required this.profileId,
    required this.isTradie,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final profileAsync = ref.watch(_profileProvider(profileId));
    final reviewsState = ref.watch(_reviewsNotifierProvider(profileId));
    final reviewsNotifier =
        ref.read(_reviewsNotifierProvider(profileId).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(child: Text('Failed to load profile')),
        data: (profile) => _ProfileBody(
          profileId: profileId,
          isTradie: isTradie,
          profile: profile,
          reviewsState: reviewsState,
          onLoadMore: reviewsNotifier.loadNext,
          isDark: isDark,
          theme: theme,
          ref: ref,
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final String profileId;
  final bool isTradie;
  final UserProfile? profile;
  final _ReviewsState reviewsState;
  final VoidCallback onLoadMore;
  final bool isDark;
  final ThemeData theme;
  final WidgetRef ref;

  const _ProfileBody({
    required this.profileId,
    required this.isTradie,
    required this.profile,
    required this.reviewsState,
    required this.onLoadMore,
    required this.isDark,
    required this.theme,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    // ── Resolved display values ────────────────────────────────────────────
    final name = profile?.fullName ??
        (isTradie ? 'Tradie Profile' : 'Homeowner Profile');
    final subtitle = isTradie
        ? (profile?.tradeType ?? 'Tradie')
        : 'Homeowner';
    final initials = profile?.initials ??
        (isTradie ? 'T' : 'H');
    final avgRating = profile?.averageRating ?? 0.0;
    final reviewCount = profile?.reviewCount ?? 0;

    final ratingLabel = avgRating > 0
        ? avgRating.toStringAsFixed(1)
        : '–';
    final isVerified = profile?.isVerified ?? false;

    return NotificationListener<ScrollNotification>(
      onNotification: (notif) {
        if (notif is ScrollEndNotification &&
            notif.metrics.pixels >= notif.metrics.maxScrollExtent - 200) {
          onLoadMore();
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignTokens.brand500,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  fontFamily: DesignTokens.fontDisplay,
                  fontWeight: FontWeight.w600,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Name + subtitle ──────────────────────────────────────────────
          Center(
            child: Text(
              name,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Center(
            child: Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Pills: Verified + Member ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isVerified) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: DesignTokens.green.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    '✓ Verified',
                    style: TextStyle(
                      fontFamily: DesignTokens.fontMono,
                      fontSize: 11,
                      color: DesignTokens.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? DesignTokens.brand100Dark
                      : DesignTokens.brand100Light,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Member',
                  style: TextStyle(
                    fontFamily: DesignTokens.fontMono,
                    fontSize: 11,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Stat cards (M4-10: aggregated rating) ─────────────────────────
          Row(
            children: [
              // Rating card
              Expanded(
                child: _StatCard(
                  isDark: isDark,
                  theme: theme,
                  label: 'Rating',
                  value: ratingLabel,
                  showStar: true,
                ),
              ),
              const SizedBox(width: 12),
              // Review count
              Expanded(
                child: _StatCard(
                  isDark: isDark,
                  theme: theme,
                  label: 'Reviews',
                  value: reviewCount.toString(),
                ),
              ),
              const SizedBox(width: 12),
              // Response (placeholder)
              Expanded(
                child: _StatCard(
                  isDark: isDark,
                  theme: theme,
                  label: 'Response',
                  value: '100%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Edit button (stub) ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Edit profile — coming soon')),
              ),
              child: const Text('Edit Profile'),
            ),
          ),
          const SizedBox(height: 24),

          // ── Reviews section header ────────────────────────────────────────
          Text(
            'Recent Reviews',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // ── Review list (M4-06: live paginated) ──────────────────────────
          if (reviewsState.reviews.isEmpty && reviewsState.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (reviewsState.reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No reviews yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else ...[
            for (final r in reviewsState.reviews)
              _ReviewCard(review: r, isDark: isDark, theme: theme),
            if (reviewsState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!reviewsState.hasMore && reviewsState.reviews.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'All reviews loaded',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],

          // ── Demo entry point for rating sheet ────────────────────────────
          TextButton(
            onPressed: () => RatingSheet.show(
              context,
              jobId: '0', // replaced by real jobId in production flow
              jobTitle: 'Fix leaking kitchen pipe',
              onSubmit: (rating, comment) =>
                  ref.read(reviewsRepositoryProvider).submitReview(
                        '0',
                        rating,
                        comment,
                        revieweeId: profileId,
                      ),
            ),
            child: const Text('Leave a review (demo)'),
          ),
        ],
      ),
    );
  }
}

// ── Stat card widget ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool showStar;
  final bool isDark;
  final ThemeData theme;

  const _StatCard({
    required this.label,
    required this.value,
    this.showStar = false,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        border: Border.all(
          color: isDark
              ? DesignTokens.paperLineDark
              : DesignTokens.paperLineLight,
        ),
      ),
      child: Column(
        children: [
          if (showStar)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star,
                    size: 18, color: DesignTokens.amberDark),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: DesignTokens.fontMono,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Text(
              value,
              style: const TextStyle(
                fontFamily: DesignTokens.fontMono,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review card widget ────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final Review review;
  final bool isDark;
  final ThemeData theme;

  const _ReviewCard({
    required this.review,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        border: Border.all(
          color: isDark
              ? DesignTokens.paperLineDark
              : DesignTokens.paperLineLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.reviewerName.isNotEmpty
                      ? review.reviewerName
                      : 'Anonymous',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                review.relativeDate,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Star display (read-only)
          Row(
            children: List.generate(5, (i) {
              final filled = i < review.rating;
              return Icon(
                Icons.star,
                size: 14,
                color: filled
                    ? DesignTokens.amberDark
                    : (isDark
                        ? DesignTokens.paperLineDark
                        : DesignTokens.paperLineLight),
              );
            }),
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comment!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
