import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../network/api_error.dart';
import '../../repositories/chat_reviews_repository.dart';
import '../../widgets/fixo_buttons.dart';
import '../widgets/sticky_action_bar.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
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
      // ── H17 sticky bar: tonal Message + primary "Request for a job" ─────
      // shown to a signed-in non-owner on any public profile — Request
      // only materialises for a homeowner viewing a tradie (the inner
      // widget loads eligible jobs itself). The body's mid-list action
      // buttons are retired in favour of this bar.
      bottomNavigationBar: !isOwner && viewerId != null && viewerId.isNotEmpty
          ? _ContextualActions(
              profileId: profileId,
              isTradie: isTradie,
              viewerRole: viewer?['role'] as int?,
              ref: ref,
              sticky: true,
            )
          : null,
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

    // H17 extras served by GET /api/profile/:id since the Bio/Registration
    // migration: About blurb, registration number, member-since date.
    final bio = profile?.bio;
    final hasBio = bio != null && bio.trim().isNotEmpty;
    final registrationNumber = profile?.registrationNumber;
    final memberSince = profile?.memberSinceUtc;
    final hasRating =
        reviewCount != null &&
        reviewCount > 0 &&
        avgRating != null &&
        avgRating > 0;

    return NotificationListener<ScrollNotification>(
      onNotification: (notif) {
        if (notif is ScrollEndNotification &&
            notif.metrics.pixels >= notif.metrics.maxScrollExtent - 200) {
          onLoadMore();
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.s6,
          Space.s4,
          Space.s6,
          Space.s7,
        ),
        children: [
          // ── Avatar — H17: 88px .av.xl solid on --av-tradie, with the ──
          // green verified tick (.vbdg) clipped bottom-right when verified.
          Center(
            child: SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 88,
                    height: 88,
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
                        fontSize: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (isVerified)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: DesignTokens.green,
                          border: Border.all(
                            color: DesignTokens.surfaceCard(isDark),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.s2_5),

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

          // ── H17 trust tile: rating + badges + stats + member-since ──────
          FixoCard(
            padding: const EdgeInsets.all(Space.s4),
            child: Column(
              children: [
                if (hasRating)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: DesignTokens.amber,
                      ),
                      const SizedBox(width: Space.s1),
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FW.bold,
                        ),
                      ),
                      const SizedBox(width: Space.s1),
                      Text(
                        '($reviewCount)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    isTradie ? 'New to Fixo' : 'Homeowner',
                    key: const Key('profile_new_to_fixo'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FW.bold,
                    ),
                  ),
                const SizedBox(height: Space.s2_5),
                // Trust badges — H17 `.badges` row: wraps, never truncated.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: Space.s2,
                  runSpacing: Space.s2,
                  children: [
                    if (isVerified)
                      _H17Badge(
                        icon: Icons.verified_user_outlined,
                        label: 'Verified',
                      ),
                    if (isVerified && isTradie)
                      _H17Badge(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Licensed',
                      ),
                    if (hasInsurance)
                      _H17Badge(icon: Icons.shield_outlined, label: 'Insured'),
                  ],
                ),
                const SizedBox(height: Space.s2),
                // Stats line: "126 jobs completed · NZ Reg #E2491" (H17).
                Text(
                  [
                    if (isTradie && reviewCount != null)
                      '$reviewCount jobs completed',
                    if (registrationNumber != null)
                      'NZ Reg #$registrationNumber',
                  ].join(' · '),
                  key: const Key('profile_stats_line'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (memberSince != null) ...[
                  const SizedBox(height: Space.s2),
                  Text(
                    'Member since ${DateFormat('MMMM yyyy').format(memberSince)}',
                    key: const Key('profile_member_since'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.s5),

          // ── About section — H17: blurb between stats and actions ──────
          if (hasBio) ...[
            Text(
              'About',
              key: const Key('profile_about_eyebrow'),
              style: TextStyle(
                fontFamily: DesignTokens.fontBody,
                fontSize: DesignTokens.fontSizeCaption,
                fontWeight: FW.semibold,
                letterSpacing: Tracking.emphasis,
                color: DesignTokens.inkSoft(isDark),
              ),
            ),
            const SizedBox(height: Space.s2),
            Text(
              bio.trim(),
              key: const Key('profile_about_body'),
              style: TextStyle(
                fontFamily: DesignTokens.fontBody,
                fontSize: DesignTokens.fontSizeBody,
                height: 1.55,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: Space.s5),
          ],

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

          // Contextual Message/Request actions moved to the H17 sticky bar
          // (Scaffold.bottomNavigationBar); Report/Block stay in the
          // app-bar overflow menu.
          const SizedBox(height: Space.s6),

          // ── Reviews section header — H17 eyebrow "Recent reviews" ──────
          Text(
            'Recent reviews',
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

  /// H17 `.btnrow` mode: tonal Message (1fr) + primary "Request for a job"
  /// (2fr) side-by-side in the sticky bar instead of stacked full-width
  /// buttons mid-list.
  final bool sticky;

  const _ContextualActions({
    required this.profileId,
    required this.isTradie,
    required this.viewerRole,
    required this.ref,
    this.sticky = false,
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
              padding: const EdgeInsets.fromLTRB(
                Space.s6,
                Space.s4,
                Space.s6,
                Space.s2,
              ),
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
        FixoNotice.warning(context, 'This job is no longer open for requests.');
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
    final canMessage = _shared != null;
    final canRequest = _requestable != null && _requestable!.isNotEmpty;
    if (!canMessage && !canRequest) return const SizedBox.shrink();

    if (widget.sticky) {
      // H17 sticky bar: `.btnrow` — tonal Message 1fr + primary 2fr.
      final message = _H17MessageButton(
        onPressed: canMessage ? _message : null,
      );
      final request = canRequest
          ? FixoPrimaryButton(
              key: const Key('request_tradie_button'),
              label: 'Request for a job',
              onPressed: _sending ? null : _request,
            )
          : null;
      return StickyActionBar(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 1, child: message),
            const SizedBox(width: Space.s2),
            Expanded(flex: 2, child: request ?? const SizedBox.shrink()),
          ],
        ),
      );
    }

    // Non-sticky fallback (inline use): same H17 row without the bar chrome.
    final message = _H17MessageButton(onPressed: canMessage ? _message : null);
    return Padding(
      padding: const EdgeInsets.only(top: Space.s2),
      child: Row(
        children: [
          Expanded(flex: 1, child: message),
          const SizedBox(width: Space.s2),
          Expanded(
            flex: 2,
            child: canRequest
                ? FixoPrimaryButton(
                    label: 'Request for a job',
                    onPressed: _sending ? null : _request,
                  )
                : const SizedBox.shrink(),
          ),
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
      FixoNotice.error(context, 'Could not check completed jobs. Try again.');
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
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: Alpha.divider,
                  ),
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
                color: theme.colorScheme.onSurface.withValues(
                  alpha: Alpha.textOnGradientStrong,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// H17 `.badge` — non-interactive status label: 26px pill, tint-brand
/// background, brand text, 14px glyph. NOT a chip (chips are interactive).
class _H17Badge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _H17Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = DesignTokens.foregroundBrand(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Space.s1),
      decoration: BoxDecoration(
        color: DesignTokens.brand500.withValues(alpha: Alpha.tintStandard),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: Space.s1),
          Text(
            label,
            style: TextStyle(
              fontFamily: DesignTokens.fontBody,
              fontSize: DesignTokens.fontSizeCaption,
              fontWeight: FW.semibold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// H17 `.btn-tonal` 56px Message button — tint-brand fill, brand text,
/// chat glyph. Rendered disabled when no open conversation exists so the
/// sticky bar keeps its 1fr shape instead of collapsing.
class _H17MessageButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _H17MessageButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = DesignTokens.foregroundBrand(isDark);
    return SizedBox(
      height: DesignTokens.heightPrimary,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.chat_bubble_outline, size: 20, color: fg),
        label: Text(
          'Message',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: DesignTokens.fontSizeControl,
            fontWeight: FW.semibold,
            color: fg,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: DesignTokens.brand500.withValues(
            alpha: Alpha.tintStandard,
          ),
          disabledBackgroundColor: DesignTokens.surfaceDisabled(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
          ),
          padding: const EdgeInsets.symmetric(horizontal: Space.s2),
        ),
      ),
    );
  }
}
