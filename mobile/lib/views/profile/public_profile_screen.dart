import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../network/api_error.dart';
import '../../repositories/chat_reviews_repository.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/rating_sheet.dart';
import '../../widgets/fixo_states.dart';
import '../../widgets/fixo_cards.dart';
import '../../feedback/fixo_notice.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Fetches public profile (with aggregated rating) for a given userId.
final _profileProvider = FutureProvider.family<UserProfile?, String>((
  ref,
  userId,
) async {
  final repo = ref.read(reviewsRepositoryProvider);
  return repo.getProfile(userId);
});

/// Paginated reviews state for a user.
class _ReviewsState {
  final List<Review> reviews;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final bool hasError;

  const _ReviewsState({
    this.reviews = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 1,
    this.hasError = false,
  });

  _ReviewsState copyWith({
    List<Review>? reviews,
    bool? isLoading,
    bool? hasMore,
    int? page,
    bool? hasError,
  }) => _ReviewsState(
    reviews: reviews ?? this.reviews,
    isLoading: isLoading ?? this.isLoading,
    hasMore: hasMore ?? this.hasMore,
    page: page ?? this.page,
    hasError: hasError ?? this.hasError,
  );
}

class _ReviewsNotifier extends StateNotifier<_ReviewsState> {
  final ReviewsRepository _repo;
  final String _userId;
  static const _pageSize = 10;

  _ReviewsNotifier(this._repo, this._userId) : super(const _ReviewsState());

  Future<void> loadNext() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, hasError: false);
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
      state = state.copyWith(isLoading: false, hasError: true);
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
    final reviewsNotifier = ref.read(
      _reviewsNotifierProvider(profileId).notifier,
    );

    final viewer = ref.watch(profileViewModelProvider).profile;
    final viewerId = viewer?['id']?.toString();
    final isOwner =
        viewerId != null && viewerId.isNotEmpty && viewerId == profileId;

    return Scaffold(
      appBar: FixoGradientAppBar(
        title: 'Profile',
        actions: [
          if (!isOwner && viewerId != null && viewerId.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'More actions',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'report') {
                  _reportUser(context, ref, profileId);
                } else if (value == 'block') {
                  _blockUser(context, ref, profileId);
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'report', child: Text('Report user')),
                PopupMenuItem(value: 'block', child: Text('Block user')),
              ],
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(child: Text('Failed to load profile')),
        data: (profile) => profile == null
            ? const FixoEmptyState(
                title: 'Profile unavailable',
                icon: Icons.person_off_outlined,
                subtitle: 'This profile could not be loaded.',
              )
            : _ProfileBody(
                profileId: profileId,
                isTradie: isTradie,
                profile: profile,
                reviewsState: reviewsState,
                onLoadMore: reviewsNotifier.loadNext,
                isDark: isDark,
                theme: theme,
                ref: ref,
                isOwner: isOwner,
                viewerId: viewerId,
                viewerRole: viewer?['role'] as int?,
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
  final bool isOwner;
  final String? viewerId;
  final int? viewerRole;

  const _ProfileBody({
    required this.profileId,
    required this.isTradie,
    required this.profile,
    required this.reviewsState,
    required this.onLoadMore,
    required this.isDark,
    required this.theme,
    required this.ref,
    required this.isOwner,
    required this.viewerId,
    required this.viewerRole,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ── Resolved display values ────────────────────────────────────────────
    final name = profile?.fullName.trim().isNotEmpty == true
        ? profile!.fullName
        : 'Name unavailable';
    final subtitle = isTradie ? (profile?.tradeType ?? 'Tradie') : 'Homeowner';
    final initials = profile?.initials ?? (isTradie ? 'T' : 'H');
    final avgRating = profile?.averageRating;
    final reviewCount = profile?.reviewCount;

    final isVerified = profile?.isVerified ?? false;
    final hasInsurance = profile?.hasInsurance ?? false;
    final isAvailable = profile?.isAvailable;

    return NotificationListener<ScrollNotification>(
      onNotification: (notif) {
        if (notif is ScrollEndNotification &&
            notif.metrics.pixels >= notif.metrics.maxScrollExtent - 200) {
          onLoadMore();
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s6, Space.s4, Space.s6, Space.s7),
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
                  fontWeight: FW.semibold,
                  fontSize: DesignTokens.fontSizeAvatarInitialsLg,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.s3),

          // ── Name + subtitle ──────────────────────────────────────────────
          Center(
            child: Text(
              name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FW.bold,
              ),
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
          const SizedBox(height: Space.s3),

          // ── Pills: Verified + Member ─────────────────────────────────────
          Wrap(
            alignment: WrapAlignment.center,
            runSpacing: 8,
            children: [
              if (isVerified) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: Space.s1),
                  decoration: BoxDecoration(
                    color: DesignTokens.green.withValues(alpha: Alpha.tintStrong),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    '✓ Verified',
                    style: TextStyle(
                      fontFamily: DesignTokens.fontBody,
                      fontSize: DesignTokens.fontSizeSecondary,
                      fontWeight: FW.semibold,
                      color: DesignTokens.inkSuccess(isDark),
                    ),
                  ),
                ),
                const SizedBox(width: Space.s2),
              ],
              if (hasInsurance) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: Space.s1),
                  decoration: BoxDecoration(
                    color: DesignTokens.brand500.withValues(alpha: Alpha.tintStandard),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: DesignTokens.brand500,
                      ),
                      const SizedBox(width: Space.s1),
                      Text(
                        'Insured',
                        style: TextStyle(
                          fontFamily: DesignTokens.fontBody,
                          fontSize: DesignTokens.fontSizeSecondary,
                          fontWeight: FW.semibold,
                          color: DesignTokens.brand500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.s2),
              ],
              if (isTradie && isAvailable != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: Space.s1),
                  decoration: BoxDecoration(
                    color: isDark
                        ? DesignTokens.brand100Dark
                        : DesignTokens.brand100Light,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    isAvailable ? 'Available for jobs' : 'Not taking jobs',
                    style: TextStyle(
                      fontFamily: DesignTokens.fontBody,
                      fontSize: DesignTokens.fontSizeSecondary,
                      fontWeight: FW.medium,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: Space.s2),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: Space.s1),
                decoration: BoxDecoration(
                  color: isDark
                      ? DesignTokens.brand100Dark
                      : DesignTokens.brand100Light,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  'Member',
                  style: TextStyle(
                    fontFamily: DesignTokens.fontBody,
                    fontSize: DesignTokens.fontSizeSecondary,
                    fontWeight: FW.medium,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s4),

          // ── Consolidated trust row ─────────────────────────────────────────
          _TrustRow(
            isDark: isDark,
            isTradie: isTradie,
            rating: (reviewCount != null && reviewCount > 0 && avgRating != null && avgRating > 0)
                ? avgRating
                : null,
            reviewCount: reviewCount ?? 0,
            isVerified: isVerified,
            hasInsurance: hasInsurance,
          ),
          const SizedBox(height: Space.s4),

          // ── Edit button ────────────────────────────────────────────────
          // Routes to the current-user edit form (PUT /api/profile).
          if (isOwner)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/profile'),
                child: const Text('Edit Profile'),
              ),
            ),
          const SizedBox(height: Space.s2),

          // ── Contextual actions for signed-in non-owners ─────────────────
          // Message stays job-scoped (existing conversation only — D5);
          // Request reuses POST /api/jobs/:id/requests and only appears for
          // a homeowner viewing a tradie while they own a Requested job.
          // Report/Block live in the app-bar overflow menu.
          if (!isOwner && viewerId != null && viewerId!.isNotEmpty)
            _ContextualActions(
              profileId: profileId,
              isTradie: isTradie,
              viewerRole: viewerRole,
              ref: ref,
            ),
          const SizedBox(height: Space.s6),

          // ── Reviews section header ────────────────────────────────────────
          Text(
            'Recent Reviews',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FW.semibold,
            ),
          ),
          const SizedBox(height: Space.s2),

          // ── Review list (M4-06: live paginated) ──────────────────────────
          if (reviewsState.reviews.isEmpty && reviewsState.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(Space.s6),
                child: CircularProgressIndicator(),
              ),
            )
          else if (reviewsState.reviews.isEmpty && !reviewsState.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s4),
              child: Center(
                child: Text(
                  'No reviews yet — reviews appear here after a completed job.',
                  textAlign: TextAlign.center,
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
                  padding: EdgeInsets.all(Space.s3),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!reviewsState.hasMore && reviewsState.reviews.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(Space.s3),
                  child: Text(
                    'All reviews loaded',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],

          if (reviewsState.hasError)
            TextButton(
              onPressed: onLoadMore,
              child: const Text('Could not load reviews. Try again.'),
            ),

          // ── Leave-a-review entry ───────────────────────────────────────
          // Opens the real rating sheet for a completed job. The jobId must
          // come from a completed-job flow — no demo jobId '0' stub.
          if (!isOwner && viewerId != null && viewerId!.isNotEmpty)
            TextButton(
              onPressed: () =>
                  _showReviewEntry(context, ref, profileId, viewerId!),
              child: const Text('Leave a review'),
            ),
        ],
      ),
    );
  }
}

// ── Contextual actions (Message / Request) ──────────────────────────────────

/// Job-scoped actions shown to a signed-in non-owner:
/// - **Message** when a conversation already exists with this user and the
///   job's chat is still open (matches IsChatOpenAsync: not Completed/
///   Cancelled/Disputed). Messaging stays job-scoped — no arbitrary DMs.
/// - **Request** when the viewer is a homeowner viewing a tradie and owns a
///   job still in `Requested` matching state. Reuses the existing
///   `POST /api/jobs/:id/requests` contract; multiple eligible jobs open a
///   chooser sheet.
class _ContextualActions extends StatefulWidget {
  final String profileId;
  final bool isTradie;
  final int? viewerRole;
  final WidgetRef ref;

  const _ContextualActions({
    required this.profileId,
    required this.isTradie,
    required this.viewerRole,
    required this.ref,
  });

  @override
  State<_ContextualActions> createState() => _ContextualActionsState();
}

class _ContextualActionsState extends State<_ContextualActions> {
  static const _chatClosed = {'Completed', 'Cancelled', 'Disputed'};

  ConversationSummary? _shared;
  List<Job>? _requestable;
  bool _sending = false;

  bool get _viewerIsHomeowner => widget.viewerRole == 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ref = widget.ref;
    try {
      final convs = await ref.read(chatRepositoryProvider).getConversations();
      final open = convs
          .where(
            (c) =>
                c.otherUserId == widget.profileId &&
                !_chatClosed.contains(c.status),
          )
          .toList();
      if (mounted) {
        setState(() => _shared = open.isEmpty ? null : open.first);
      }
    } catch (_) {
      // No conversations load → Message simply stays hidden.
    }
    if (widget.isTradie && _viewerIsHomeowner) {
      try {
        final jobs = await ref
            .read(jobsRepositoryProvider)
            .getMyJobs(status: 'Requested');
        final open = jobs.where((j) => j.status == 'Requested').toList();
        if (mounted) setState(() => _requestable = open);
      } catch (_) {
        if (mounted) setState(() => _requestable = const []);
      }
    }
  }

  Future<void> _message() async {
    final jobId = _shared?.jobId;
    if (jobId == null) return;
    await context.push('/chat/$jobId');
  }

  Future<void> _request() async {
    final eligible = _requestable;
    if (eligible == null || eligible.isEmpty || _sending) return;
    Job? job = eligible.length == 1 ? eligible.first : null;
    job ??= await showModalBottomSheet<Job>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s6, Space.s4, Space.s6, Space.s2),
              child: Text(
                'Request this tradie',
                style: Theme.of(ctx).textTheme.titleMedium
                    ?.copyWith(fontWeight: FW.semibold),
              ),
            ),
            for (final j in eligible)
              ListTile(
                title: Text(j.title),
                subtitle: j.suburb.isNotEmpty ? Text(j.suburb) : null,
                onTap: () => Navigator.pop(ctx, j),
              ),
          ],
        ),
      ),
    );
    if (job == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final ok = await widget.ref
          .read(jobsRepositoryProvider)
          .requestTradie(job.id, widget.profileId);
      if (!mounted) return;
      if (ok) {
        FixoNotice.success(
          context,
          'Request sent — you’ll be notified when they respond.',
        );
      } else {
        FixoNotice.warning(
          context,
          'This job is no longer open for requests.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      FixoNotice.error(context, NoticeCopy.requestFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (_shared != null)
        OutlinedButton.icon(
          onPressed: _message,
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: const Text('Message'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, DesignTokens.heightSecondary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
            ),
          ),
        ),
      if (_requestable != null && _requestable!.isNotEmpty)
        FilledButton.icon(
          onPressed: _sending ? null : _request,
          icon: const Icon(Icons.handshake_outlined, size: 18),
          label: const Text('Request this tradie'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, DesignTokens.heightPrimary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
            ),
          ),
        ),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Space.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: Space.s2),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// Finds the viewer's most recent Complete job and opens the real rating
/// sheet (POST /api/jobs/:id/reviews). Shows a message when no completed
/// job exists instead of submitting to a stub jobId.
Future<void> _showReviewEntry(
  BuildContext context,
  WidgetRef ref,
  String profileId,
  String viewerId,
) async {
  List<Job> jobs;
  try {
    jobs = await ref.read(jobsRepositoryProvider).getMyJobs();
  } catch (_) {
    if (context.mounted) {
      FixoNotice.error(
        context,
        'Could not check completed jobs. Try again.',
      );
    }
    return;
  }
  final completed = jobs
      .where(
        (j) =>
            j.status == 'Completed' &&
            ((j.homeownerId == viewerId && j.matchedTradieId == profileId) ||
                (j.matchedTradieId == viewerId && j.homeownerId == profileId)),
      )
      .toList();
  if (!context.mounted) return;
  if (completed.isEmpty) {
    FixoNotice.info(context, NoticeCopy.reviewsLocked);
    return;
  }
  final job = completed.first;
  if (!context.mounted) return;
  RatingSheet.show(
    // ignore: use_build_context_synchronously
    context,
    jobId: job.id,
    jobTitle: job.title,
    onSubmit: (rating, comment) => ref
        .read(reviewsRepositoryProvider)
        .submitReview(job.id, rating, comment, revieweeId: profileId),
  );
}

/// P8-02: report this profile for abuse (Abuse flag for staff triage).
Future<void> _reportUser(
  BuildContext context,
  WidgetRef ref,
  String profileId,
) async {
  final reasonCtrl = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Report abuse'),
      content: TextField(
        controller: reasonCtrl,
        decoration: const InputDecoration(
          hintText: 'What happened? (optional)',
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, reasonCtrl.text.trim()),
          child: const Text('Report'),
        ),
      ],
    ),
  );
  if (reason == null) return;
  try {
    await ref
        .read(profileRepositoryProvider)
        .reportUser(profileId, reason: reason);
    if (!context.mounted) return;
    FixoNotice.success(context, NoticeCopy.reportSent);
  } catch (e) {
    if (!context.mounted) return;
    final msg = e is DioException
        ? friendlyDioError(e, tag: 'PublicProfile.report')
        : e.toString();
    FixoNotice.errorDynamic(context, msg);
  }
}

/// P8-02: block this profile (excluded from future matches both ways).
Future<void> _blockUser(
  BuildContext context,
  WidgetRef ref,
  String profileId,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Block user?'),
      content: const Text('You will no longer be matched with this user.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (confirm != true) return;
  try {
    await ref.read(profileRepositoryProvider).blockUser(profileId);
    if (!context.mounted) return;
    FixoNotice.info(context, NoticeCopy.userBlocked);
  } catch (e) {
    if (!context.mounted) return;
    final msg = e is DioException
        ? friendlyDioError(e, tag: 'PublicProfile.block')
        : e.toString();
    FixoNotice.errorDynamic(context, msg);
  }
}

// ── Trust row widget ──────────────────────────────────────────────────────────

class _TrustRow extends StatelessWidget {
  final bool isDark;
  final bool isTradie;
  final double? rating;
  final int reviewCount;
  final bool isVerified;
  final bool hasInsurance;

  const _TrustRow({
    required this.isDark,
    required this.isTradie,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.hasInsurance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRating = rating != null && rating! > 0 && reviewCount > 0;

    return FixoCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: 14),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            if (hasRating)
              Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(Icons.star_rounded, size: 20, color: DesignTokens.amber),
                    ),
                    const WidgetSpan(child: SizedBox(width: Space.s1)),
                    TextSpan(
                      text: rating!.toStringAsFixed(1),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FW.bold,
                      ),
                    ),
                    const WidgetSpan(child: SizedBox(width: Space.s1)),
                    TextSpan(
                      text: '($reviewCount)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              )
            else
              Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(Icons.verified_user_outlined, size: 18, color: DesignTokens.amber),
                    ),
                    const WidgetSpan(child: SizedBox(width: Space.s1_5)),
                    TextSpan(
                      text: 'New to TradieHunter',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FW.semibold,
                        color: isDark ? Colors.white : DesignTokens.brand900,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            if (isTradie && isVerified)
              Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(Icons.verified_outlined, size: 18, color: DesignTokens.inkSuccess(isDark)),
                    ),
                    const WidgetSpan(child: SizedBox(width: Space.s1)),
                    TextSpan(
                      text: 'Verified',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FW.semibold,
                        color: DesignTokens.inkSuccess(isDark),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            if (isTradie && hasInsurance)
              Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(Icons.shield_outlined, size: 18, color: DesignTokens.brand500),
                    ),
                    const WidgetSpan(child: SizedBox(width: Space.s1)),
                    TextSpan(
                      text: 'Insured',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FW.semibold,
                        color: DesignTokens.brand500,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
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
      margin: const EdgeInsets.only(bottom: Space.s3),
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceCard(isDark),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
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
                    fontSize: DesignTokens.fontSizeSm,
                    fontWeight: FW.semibold,
                  ),
                ),
              ),
              Text(
                review.relativeDate,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: Alpha.divider),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s1),
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
            const SizedBox(height: Space.s1_5),
            Text(
              review.comment!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: Alpha.textOnGradientStrong),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
