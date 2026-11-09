import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../theme/design_tokens.dart';
import '../../utils/money.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../../widgets/fixo_states.dart';
import '../widgets/job_navigation.dart';
import '../widgets/sticky_action_bar.dart';
import '../widgets/fixo_feedback.dart';


/// H11 Match Result — heroband with route-line watermark, tradie card whose
/// avatar overlaps the band bottom edge, tinted price summary, sticky CTAs.
/// All data/navigation logic is unchanged from the pre-v1.6 version.
class MatchResultScreen extends ConsumerStatefulWidget {
  final String jobId;
  const MatchResultScreen({super.key, required this.jobId});

  @override
  ConsumerState<MatchResultScreen> createState() => _MatchResultScreenState();
}

class _MatchResultScreenState extends ConsumerState<MatchResultScreen> {
  bool _loading = true;
  bool _requesting = false;
  bool _requested = false;
  List<TradieMatch> _matches = const [];
  Job? _job;
  String? _error;
  int _selectedMatchIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(jobsRepositoryProvider);
      // The job supplies hours/rate/total and the status that makes the
      // Request action state-aware; matches supply the named identity cards.
      final results = await Future.wait([
        repo.getMatches(widget.jobId),
        repo.getJobById(widget.jobId),
      ]);
      if (!mounted) return;
      setState(() {
        _matches = results[0] as List<TradieMatch>;
        _job = results[1] as Job?;
        _loading = false;
      });
    });
  }

  Future<void> _request(TradieMatch match) async {
    setState(() {
      _requesting = true;
      _error = null;
    });
    final ok = await ref
        .read(jobsRepositoryProvider)
        .requestTradie(widget.jobId, match.tradieId);
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _requested = ok;
      _error = ok
          ? null
          : 'Couldn\'t send the request. Check your connection and try again.';
    });
    if (ok) context.push('/chat/${widget.jobId}');
  }

  /// The primary action follows the job's real status — a job that already
  /// has an accepted offer or is booked never offers another Request.
  Widget _primaryAction() {
    final status = _job?.status;
    if (_requested || status == 'AwaitingPayment' || status == 'Matched') {
      return FixoPrimaryButton(
        label: 'Continue to payment',
        onPressed: () => context.push('/jobs/${widget.jobId}/payment'),
      );
    }
    if (status == 'Booked' ||
        status == 'InProgress' ||
        status == 'AwaitingConfirmation' ||
        status == 'Completed' ||
        status == 'PaymentReview') {
      return FixoPrimaryButton(
        label: 'View job',
        onPressed: () {
          final job = _job;
          if (job != null) openHomeownerJob(context, job);
        },
      );
    }
    final top = _matches.isNotEmpty
        ? _matches[_selectedMatchIndex < _matches.length ? _selectedMatchIndex : 0]
        : null;
    if (top == null) return const SizedBox.shrink();
    return FixoPrimaryButton(
      label: top.name.trim().isEmpty
          ? 'Request this tradie'
          : 'Request ${top.name.trim().split(' ').first}',
      isLoading: _requesting,
      onPressed: () => _request(top),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(body: FixoLoading());
    }

    if (_matches.isEmpty) {
      return Scaffold(
        appBar: const FixoGradientAppBar(title: 'No matches yet'),
        body: FixoEmptyState(
          icon: Icons.search_off,
          title: 'No tradies available',
          subtitle:
              'We couldn\'t find a verified, available tradie in range. '
              'Try again later.',
          actionLabel: 'Back to jobs',
          onAction: () => context.pop(),
        ),
        bottomNavigationBar: Container(
          color: DesignTokens.surfaceCard(isDark),
          height: MediaQuery.of(context).padding.bottom,
        ),
      );
    }

    final currentMatch = _matches[
        _selectedMatchIndex < _matches.length ? _selectedMatchIndex : 0];
    final terminal =
        _job?.status == 'Cancelled' ||
        _job?.status == 'Expired' ||
        _job?.status == 'Disputed';

    return Scaffold(
      backgroundColor:
          isDark ? DesignTokens.cardDark : DesignTokens.paperLight,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light
            .copyWith(statusBarColor: Colors.transparent),
        child: Column(
          children: [
            // ── H11 heroband ──────────────────────────────────────────
            const _HeroBand(),

            // ── Tradie card with overlapping avatar ───────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Avatar overlaps the heroband bottom by 36px (half of 72px avatar)
                  Transform.translate(
                    offset: const Offset(0, -_avatarOverlap),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      child: Column(
                        children: [
                          _MatchCard(
                            match: currentMatch,
                            isDark: isDark,
                            onViewProfile: currentMatch.tradieId.isEmpty
                                ? null
                                : () => context
                                    .push('/tradie/${currentMatch.tradieId}'),
                          ),
                          if (_job != null &&
                              (_job!.totalAmount != null ||
                                  _job!.hourlyRate != null)) ...[
                            const SizedBox(height: 14),
                            _PriceSummaryCard(job: _job!, isDark: isDark),
                          ],
                          const SizedBox(height: Space.s6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: terminal
          ? Container(
              color: DesignTokens.surfaceCard(isDark),
              height: MediaQuery.of(context).padding.bottom,
            )
          : StickyActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s2),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  _primaryAction(),
                  if (_matches.length > 1) ...[
                    const SizedBox(height: Space.s2),
                    FixoGhostButton(
                      label: 'See another tradie',
                      onPressed: () {
                        setState(() {
                          _selectedMatchIndex =
                              (_selectedMatchIndex + 1) % _matches.length;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ── H11 hero band ─────────────────────────────────────────────────────────────

/// Flat brand band holding the back button and the headline. The headline is
/// in normal flow (not absolutely positioned) so it can wrap at any text
/// scale, and the bottom padding reserves the avatar overlap so the card
/// never covers it.
class _HeroBand extends StatelessWidget {
  const _HeroBand();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        Space.s2,
        top + Space.s2,
        Space.gutter,
        _avatarOverlap + Space.s4,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DesignTokens.brand700, DesignTokens.brand500],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            constraints: const BoxConstraints(
              minWidth: Sizes.tapMin,
              minHeight: Sizes.tapMin,
            ),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: Space.s1),
          const Expanded(
            child: Text(
              'We found your tradie',
              style: TextStyle(
                fontFamily: DesignTokens.fontDisplay,
                fontSize: DesignTokens.fontSizeH2Small,
                fontWeight: FW.semibold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How far the tradie card (and its avatar) rides up over the hero band.
const double _avatarOverlap = Sizes.avatarLg / 2;

// ── Tradie card with overlapping avatar ───────────────────────────────────────

/// Centered card whose 72×72 avatar visually overlaps the heroband above.
/// The parent uses `Transform.translate(offset: Offset(0, -36))` to shift
/// the whole column up by half the avatar height.
class _MatchCard extends StatelessWidget {
  final TradieMatch match;
  final bool isDark;
  final VoidCallback? onViewProfile;
  const _MatchCard({
    required this.match,
    required this.isDark,
    this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = match.name.trim().isEmpty ? 'Name unavailable' : match.name;
    final initials = match.initials.trim().isEmpty ? '?' : match.initials;

    return FixoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Top section: avatar (overlaps heroband) + name + chips
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.s5),
            child: Column(
              children: [
                // Avatar — sits at top, overlaps heroband via parent translate
                Container(
                  width: Sizes.avatarLg,
                  height: Sizes.avatarLg,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: DesignTokens.brand500,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontFamily: DesignTokens.fontDisplay,
                      fontSize: DesignTokens.fontSizeAvatarInitials,
                      fontWeight: FW.semibold,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: Space.s2),

                // Name
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: DesignTokens.fontDisplay,
                    fontSize: DesignTokens.fontSizeH2,
                    fontWeight: FW.bold,
                    color: DesignTokens.foregroundBrand(isDark),
                  ),
                ),

                if (match.trade.trim().isNotEmpty) ...[
                  const SizedBox(height: Space.s0_5),
                  Text(
                    match.trade,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],

                // Verified / Insured chips
                if (match.verified || match.hasInsurance) ...[
                  const SizedBox(height: Space.s2_5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      if (match.verified)
                        FixoPillChip(
                          icon: Icons.check_circle_outline,
                          label: 'Verified',
                          color: DesignTokens.inkSuccess(isDark),
                          bordered: false,
                        ),
                      if (match.hasInsurance)
                        FixoPillChip(
                          icon: Icons.shield_outlined,
                          label: 'Insured',
                          color: DesignTokens.foregroundBrand(isDark),
                          bordered: false,
                        ),
                    ],
                  ),
                ],

                // Rating / distance row
                const SizedBox(height: Space.s2_5),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 0,
                  runSpacing: 4,
                  children: [
                    if (match.rating != null && (match.rating ?? 0) > 0) ...[
                      Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: DesignTokens.amber,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        match.rating!.toStringAsFixed(1),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FW.semibold,
                        ),
                      ),
                      if (match.reviewCount != null &&
                          match.reviewCount! > 0) ...[
                        Text(
                          ' (${match.reviewCount} ${match.reviewCount == 1 ? 'job' : 'jobs'})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (match.hasDistance) ...[
                        Text(
                          ' · ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ] else ...[
                      Text(
                        'New to TradieHunter',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: DesignTokens.foregroundBrand(isDark),
                          fontWeight: FW.semibold,
                        ),
                      ),
                      if (match.hasDistance)
                        Text(
                          ' · ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                    if (match.hasDistance)
                      Text(
                        match.distance,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          if (onViewProfile != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s2),
              child: TextButton(
                key: const Key('view_profile_button'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(Sizes.tapMin, Sizes.tapMin),
                ),
                onPressed: onViewProfile,
                child: const Text('View profile'),
              ),
            ),

          // Bio (if present) — separated by hairline
          if (match.bio != null && match.bio!.trim().isNotEmpty) ...[
            Divider(
              height: 1,
              color: DesignTokens.paperLine(isDark),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 14, Space.gutter, Space.s4),
              child: Text(
                match.bio!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Price summary card ────────────────────────────────────────────────────────

/// Tinted brand-wash card showing the hourly breakdown, a divider, the total,
/// and the "Pay after the job" caption — matching H11's price card design.
class _PriceSummaryCard extends StatelessWidget {
  final Job job;
  final bool isDark;
  const _PriceSummaryCard({required this.job, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBreakdown = job.hours > 0 && job.hourlyRate != null;
    final hasTotal = job.totalAmount != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? DesignTokens.brand500.withValues(alpha: Alpha.tintStandard)
            : DesignTokens.brand500.withValues(alpha: Alpha.wash),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(
          color: DesignTokens.paperLine(isDark),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasBreakdown)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s4, Space.gutter, 0),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: DesignTokens.inkSoft(isDark),
                  ),
                  Text(
                    '${job.hours} h',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: DesignTokens.inkSoft(isDark),
                    ),
                  ),
                  Text(
                    '×',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: DesignTokens.inkSoft(isDark),
                    ),
                  ),
                  Text(
                    formatRate(job.hourlyRate!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: DesignTokens.inkSoft(isDark),
                    ),
                  ),
                ],
              ),
            ),

          if (hasBreakdown && hasTotal)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s2_5),
              child: Divider(height: 1, color: DesignTokens.paperLine(isDark)),
            ),

          if (hasTotal)
            Padding(
              padding: EdgeInsets.fromLTRB(Space.gutter, hasBreakdown ? 0: Space.s4, Space.s5, Space.s1_5),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Estimated total',
                    style: TextStyle(
                      fontFamily: DesignTokens.fontDisplay,
                      fontSize: DesignTokens.fontSizeH3,
                      fontWeight: FW.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatMoney(job.totalAmount!),
                      style: TextStyle(
                        fontFamily: DesignTokens.fontDisplay,
                        fontSize: DesignTokens.fontSizeAmount,
                        fontWeight: FW.bold,
                        color: DesignTokens.foregroundBrand(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s1, Space.gutter, 14),
            child: Text(
              'Pay after the job — by bank transfer, checked by us',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared chip ───────────────────────────────────────────────────────────────

