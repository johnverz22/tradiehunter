import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../theme/design_tokens.dart';
import '../../utils/money.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../../widgets/fixo_states.dart';
import '../widgets/fixo_filter_bar.dart';
import '../widgets/fixo_filter_pill.dart';
import '../widgets/job_status_presentation.dart';
import '../widgets/sticky_action_bar.dart';
import '../../feedback/fixo_notice.dart';

/// Choose-a-Tradie screen (v1.7 P12-06, design frame H19).
///
/// Route: `/jobs/:jobId/tradies`. Lists the server-ranked tradies for this
/// job (contract #2) with sort + filter pills, opens a tradie's profile in
/// job context on tap, and offers "Quick match for me" which starts the
/// existing auto-match run (POST /api/jobs/:id/match → matching screen).
///
/// Rates carry the D8 GST label — "Incl. GST" / "No GST charged" — and are
/// omitted entirely when the server sent no rate (never fabricated).
class TradieListScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TradieListScreen({super.key, required this.jobId});

  @override
  ConsumerState<TradieListScreen> createState() => _TradieListScreenState();
}

class _TradieListScreenState extends ConsumerState<TradieListScreen> {
  bool _startingMatch = false;

  Future<void> _startQuickMatch() async {
    if (_startingMatch) return;
    setState(() => _startingMatch = true);
    // Same auto-match path as before v1.7: the server runs the sequential
    // offer engine; the matching screen renders its SignalR progress.
    final started = await ref
        .read(jobsRepositoryProvider)
        .triggerMatch(widget.jobId);
    if (!mounted) return;
    setState(() => _startingMatch = false);
    if (started) {
      context.push('/jobs/${widget.jobId}/matching');
    } else {
      FixoNotice.warning(
        context,
        'Quick match could not start for this job — it may already be booked.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(tradieListProvider(widget.jobId));
    final notifier = ref.read(tradieListProvider(widget.jobId).notifier);

    return Scaffold(
      appBar: const FixoGradientAppBar(title: 'Choose a Tradie'),
      body: Column(
        children: [
          // ── Sort bar (server-ranked; "best" = server score) ──────────────
          FixoFilterBar<TradieListSort>(
            items: TradieListSort.values,
            selectedItem: state.sort,
            labelBuilder: (sort) => sort.label,
            onSelected: notifier.setSort,
            listKey: const Key('tradie_sort_bar'),
          ),
          // ── Filter pills (verified / insured / available now) ────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s4),
            child: Wrap(
              spacing: Space.s2,
              runSpacing: Space.s2,
              children: [
                FixoFilterPill(
                  pillKey: const Key('tradie_filter_verified'),
                  label: 'Verified',
                  selected: state.verifiedOnly,
                  onSelected: (_) => notifier.toggleVerified(),
                ),
                FixoFilterPill(
                  pillKey: const Key('tradie_filter_insured'),
                  label: 'Insured',
                  selected: state.insuredOnly,
                  onSelected: (_) => notifier.toggleInsured(),
                ),
                FixoFilterPill(
                  pillKey: const Key('tradie_filter_available'),
                  label: 'Available now',
                  selected: state.availableNowOnly,
                  onSelected: (_) => notifier.toggleAvailableNow(),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s2),
          Expanded(
            child: state.isLoading && state.tradies.isEmpty
                ? const FixoLoading(label: 'Finding tradies…')
                : state.error != null && state.tradies.isEmpty
                ? FixoErrorState(
                    message: 'Could not load tradies for this job.',
                    onRetry: notifier.load,
                  )
                : state.tradies.isEmpty
                ? FixoEmptyState(
                    icon: Icons.search_off_outlined,
                    title: 'No tradies match yet',
                    subtitle:
                        'Try removing a filter, or use Quick match '
                        'to let us contact tradies for you.',
                    actionLabel: 'Clear filters',
                    onAction: () {
                      if (state.verifiedOnly ||
                          state.insuredOnly ||
                          state.availableNowOnly) {
                        if (state.verifiedOnly) notifier.toggleVerified();
                        if (state.insuredOnly) notifier.toggleInsured();
                        if (state.availableNowOnly) {
                          notifier.toggleAvailableNow();
                        }
                      } else {
                        notifier.load();
                      }
                    },
                  )
                : RefreshIndicator(
                    onRefresh: notifier.load,
                    child: ListView.separated(
                      key: const Key('tradie_list'),
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        Space.s2,
                        Space.gutter,
                        Space.stickyBarClearance,
                      ),
                      itemCount: state.tradies.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Space.s4),
                      itemBuilder: (context, index) => _TradieCard(
                        entry: state.tradies[index],
                        isDark: isDark,
                        onTap: () => context.push(
                          '/tradie/${state.tradies[index].tradieId}'
                          '?jobId=${widget.jobId}',
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        child: FixoPrimaryButton(
          key: const Key('quick_match_button'),
          label: 'Quick match for me',
          isLoading: _startingMatch || state.isLoading,
          onPressed: _startingMatch ? null : _startQuickMatch,
        ),
      ),
    );
  }
}

/// H19 tradie card: initials avatar with verified badge, name + availability
/// pill, trade·distance line, divider, rating row and hourly rate with the
/// GST label (D8).
class _TradieCard extends StatelessWidget {
  final TradieListEntry entry;
  final bool isDark;
  final VoidCallback onTap;

  const _TradieCard({
    required this.entry,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<THColors>()!;
    final hasRating =
        entry.rating != null &&
        entry.rating! > 0 &&
        (entry.reviewCount ?? 0) > 0;

    // Availability: a real boolean from the server — "Available" pill when
    // true, "Next availability" muted text when false. Never invented.
    final availability = entry.available ? 'Available' : null;

    return FixoCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with verified badge overlay (H19 .av + .vbdg)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: Sizes.avatarRadius * 2,
                        height: Sizes.avatarRadius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.avTradie,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          entry.initials.isEmpty ? '?' : entry.initials,
                          style: TextStyle(
                            fontFamily: TypeTokens.fontDisplay,
                            fontSize: DesignTokens.fontSizeH3,
                            fontWeight: FW.semibold,
                            color: colors.onAvTradie,
                          ),
                        ),
                      ),
                      if (entry.verified)
                        Positioned(
                          right: -Space.s0_5,
                          bottom: -Space.s0_5,
                          child: Container(
                            width: Sizes.avatarBadge,
                            height: Sizes.avatarBadge,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.success,
                              border: Border.all(
                                color: colors.surface,
                                width: Sizes.borderWidthThin,
                              ),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: Sizes.iconChip,
                              color: colors.onBrand,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FW.bold,
                                ),
                              ),
                            ),
                            if (availability != null)
                              StatusChip(
                                label: availability,
                                tone: ChipTone.success,
                                icon: Icons.event_available_rounded,
                              ),
                          ],
                        ),
                        const SizedBox(height: Space.s0_5),
                        Text(
                          _metaLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s3),
              Divider(height: Sizes.borderWidthThin, color: colors.line),
              const SizedBox(height: Space.s2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Rating: "(48 jobs)" per H19 — real counts only.
                  Flexible(
                    child: hasRating
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: Sizes.iconRating,
                                color: DesignTokens.amber,
                              ),
                              const SizedBox(width: Sizes.ratingGap),
                              Flexible(
                                child: Text(
                                  '${entry.rating!.toStringAsFixed(1)} '
                                  '(${entry.completedJobs ?? entry.reviewCount} jobs)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FW.bold,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            (entry.completedJobs ?? 0) > 0
                                ? '${entry.completedJobs} jobs completed'
                                : 'New to Fixo',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  // Rate + GST label (D8): rate is omitted when the server
                  // sent none — never a fabricated $0.
                  Flexible(
                    child: entry.hourlyRate == null
                        ? const SizedBox.shrink()
                        : Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: formatRate(entry.hourlyRate!),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FW.bold,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                if (gstLabelFor(entry.isGstRegistered)
                                    case final gstLabel?) ...[
                                  const TextSpan(text: '  '),
                                  TextSpan(
                                    text: gstLabel,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _metaLine {
    // Distance string is server-rendered when present ("1.2 km away").
    final distance = entry.distance.trim().isNotEmpty
        ? entry.distance.trim()
        : (entry.distanceKm > 0
              ? '${entry.distanceKm.toStringAsFixed(1)} km away'
              : '');
    return distance.isEmpty ? 'Distance unavailable' : distance;
  }
}
