// Section widgets for the v2 tradie home (`tr_home`, plan 5.1). Pure
// presentation: every callback and value comes from `tr_home_screen.dart`.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'tr_home_mapper.dart';
import 'tr_job_card.dart';
import 'tr_lead_card.dart';

/// Hero: greeting, online switch, weekly net and rating badge.
class TrHomeHero extends StatelessWidget {
  const TrHomeHero({
    super.key,
    required this.greeting,
    required this.online,
    required this.switchEnabled,
    required this.onToggle,
    required this.net,
    required this.onRetryEarnings,
    this.rating,
  });

  final String greeting;
  final bool online;
  final bool switchEnabled;
  final VoidCallback onToggle;
  final TrHeroNet net;
  final VoidCallback onRetryEarnings;
  final ({String score, int count})? rating;

  @override
  Widget build(BuildContext context) {
    final netText = switch (net.kind) {
      TrNetKind.loading => '…',
      TrNetKind.error => 'Unavailable — tap to retry',
      TrNetKind.unavailable => 'Not available',
      TrNetKind.loaded => formatMoney(net.amount!),
    };
    final isMoney = net.kind == TrNetKind.loaded;
    return THHero(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: Space.s3,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 2.0,
                children: [
                  THText(greeting, style: THTextStyle.label, tone: THTone.gold),
                  THText(
                    online ? 'You’re online' : 'You’re paused',
                    style: THTextStyle.h2,
                    tone: THTone.onHero,
                  ),
                ],
              ),
            ),
            Semantics(
              label: online
                  ? 'Online, accepting new job offers'
                  : 'Offline, not accepting new job offers',
              child: THSwitch(
                key: const Key('availability_button'),
                on: online,
                onChanged: switchEnabled ? (_) => onToggle() : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.s4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const THText(
                    'Net this week',
                    style: THTextStyle.meta,
                    tone: THTone.onHeroSoft,
                  ),
                  InkWell(
                    onTap: net.kind == TrNetKind.error ? onRetryEarnings : null,
                    child: THText(
                      netText,
                      style: isMoney ? THTextStyle.moneyLg : THTextStyle.title,
                      tone: THTone.onHero,
                    ),
                  ),
                ],
              ),
            ),
            if (rating != null)
              THBadge(
                '${rating!.score} · ${rating!.count}',
                kind: THBadgeKind.glass,
                icon: Icons.star_rounded,
              ),
          ],
        ),
      ],
    );
  }
}

/// Stat tiles. Only tiles backed by a real value are drawn (plan G-13): no
/// response-rate tile, no placeholder figures.
class TrStatTiles extends StatelessWidget {
  const TrStatTiles({
    super.key,
    required this.weekJobs,
    required this.pending,
    required this.rating,
  });

  final int weekJobs;
  final Decimal? pending;
  final ({String score, int count})? rating;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _Tile(value: '$weekJobs', label: 'Jobs this week'),
      if (pending != null)
        _Tile(
          key: const Key('stat_tile_pending'),
          value: formatMoney(pending!),
          label: 'Outstanding',
        ),
      if (rating != null)
        _Tile(
          key: const Key('stat_tile_rating'),
          value: rating!.score,
          label: 'Rating',
        ),
    ];
    // IntrinsicHeight: a stretch row inside the scrolling column would force
    // an infinite height (same fix as auth_common.dart).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s2_5,
        children: [for (final t in tiles) Expanded(child: t)],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label: $value',
    excludeSemantics: true,
    child: THCard(
      padding: Space.s3,
      children: [
        THText(value, style: THTextStyle.money),
        THText(label, style: THTextStyle.meta, tone: THTone.soft, size: 12.0),
      ],
    ),
  );
}

/// "You're currently paused" banner (copy from v1).
class TrPausedBanner extends StatelessWidget {
  const TrPausedBanner({super.key});

  @override
  Widget build(BuildContext context) => const THCard(
    tone: THCardTone.accent,
    padding: Space.s3,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: Space.s2,
        children: [
          THIcon(Icons.pause_circle_outline_rounded, tone: THTone.accent),
          Expanded(
            child: THText(
              'You’re currently paused. Toggle back on to receive new job '
              'offers.',
              style: THTextStyle.meta,
            ),
          ),
        ],
      ),
    ],
  );
}

/// "Not verified yet" banner with a link into the setup wizard.
class TrVerificationBanner extends StatelessWidget {
  const TrVerificationBanner({super.key, required this.onReview});
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => THCard(
    tone: THCardTone.accent,
    padding: Space.s4,
    children: [
      const THText('Not verified yet', style: THTextStyle.title),
      const SizedBox(height: Space.s1),
      const THText(
        'Upload a licence or insurance so an admin can approve you. '
        'Unverified tradies are never matched to jobs.',
        style: THTextStyle.meta,
        tone: THTone.soft,
      ),
      const SizedBox(height: Space.s3),
      THButton(
        label: 'Review my setup',
        kind: THButtonKind.accent,
        size: THButtonSize.sm,
        onPressed: onReview,
      ),
    ],
  );
}

/// Section heading with an optional count badge.
class TrSectionLabel extends StatelessWidget {
  const TrSectionLabel(
    this.title, {
    super.key,
    this.count,
    this.accent = false,
  });
  final String title;
  final int? count;
  final bool accent;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: THText(title, style: THTextStyle.title)),
      if (count != null && count! > 0)
        THBadge(
          '$count',
          kind: accent ? THBadgeKind.accent : THBadgeKind.brand,
        ),
    ],
  );
}

/// New leads: hidden when loaded, empty and error-free; checking row on first
/// load; error row with retry; otherwise one animated lead card per lead.
class TrLeadsSection extends StatelessWidget {
  const TrLeadsSection({
    super.key,
    required this.leads,
    required this.pendingOffers,
    required this.offersLoaded,
    required this.hasError,
    required this.isFirstLoad,
    required this.responding,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
    required this.onExpired,
    required this.onRetry,
  });

  final List<Job> leads;
  final Map<String, JobOffer?> pendingOffers;
  final bool offersLoaded;
  final bool hasError;
  final bool isFirstLoad;
  final Set<String> responding;
  final void Function(Job) onAccept;
  final void Function(Job) onDecline;
  final void Function(Job) onOpen;
  final VoidCallback onExpired;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isFirstLoad) {
      return const THCard(
        children: [THText('Checking for new leads…', style: THTextStyle.meta)],
      );
    }
    if (hasError && leads.isEmpty) {
      return THCard(
        children: [
          const THText(
            'Could not load new leads.',
            style: THTextStyle.meta,
            tone: THTone.danger,
          ),
          const SizedBox(height: Space.s2),
          THButton(
            label: 'Try again',
            kind: THButtonKind.secondary,
            size: THButtonSize.sm,
            onPressed: onRetry,
          ),
        ],
      );
    }
    if (leads.isEmpty) return const SizedBox.shrink();
    final duration = THMotion.duration(context, THDurations.base);
    return AnimatedSize(
      duration: duration,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s2_5,
        children: [
          TrSectionLabel('New leads', count: leads.length, accent: true),
          for (final job in leads)
            AnimatedSwitcher(
              key: ValueKey<String>('lead_${job.id}'),
              duration: duration,
              child: TrLeadCard(
                key: ValueKey<String>('lead_card_${job.id}'),
                job: job,
                offer: pendingOffers[job.id],
                offerChecked: offersLoaded && pendingOffers.containsKey(job.id),
                busy: responding.contains(job.id),
                onAccept: () => onAccept(job),
                onDecline: () => onDecline(job),
                onOpen: () => onOpen(job),
                onExpired: onExpired,
              ),
            ),
        ],
      ),
    );
  }
}

/// A heading plus one [TrJobCard] per job.
class TrJobCards extends StatelessWidget {
  const TrJobCards({
    super.key,
    required this.jobs,
    required this.onTap,
    this.overdue = false,
  });
  final List<Job> jobs;
  final void Function(Job) onTap;
  final bool overdue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: Space.s2_5,
    children: [
      for (final job in jobs)
        TrJobCard(
          key: ValueKey<String>('job_card_${job.id}'),
          job: job,
          isOverdueOverride: overdue ? true : null,
          onTap: () => onTap(job),
        ),
    ],
  );
}

/// Today's jobs, or an empty state that offers going online when paused.
class TrTodaySection extends StatelessWidget {
  const TrTodaySection({
    super.key,
    required this.jobs,
    required this.online,
    required this.onTap,
    required this.onGoOnline,
  });
  final List<Job> jobs;
  final bool online;
  final void Function(Job) onTap;
  final VoidCallback onGoOnline;

  @override
  Widget build(BuildContext context) {
    if (jobs.isNotEmpty) return TrJobCards(jobs: jobs, onTap: onTap);
    return THCard(
      children: [
        THText(
          online ? 'No jobs today' : 'You’re offline',
          style: THTextStyle.title,
        ),
        const SizedBox(height: Space.s1),
        THText(
          online
              ? 'New leads will appear here as they arrive.'
              : 'Go online to receive new job offers.',
          style: THTextStyle.meta,
          tone: THTone.soft,
        ),
        if (!online) ...[
          const SizedBox(height: Space.s3),
          THButton(
            label: 'Go online',
            kind: THButtonKind.accent,
            size: THButtonSize.sm,
            onPressed: onGoOnline,
          ),
        ],
      ],
    );
  }
}

/// Collapsible group (Upcoming / Awaiting payment / Needs attention).
class TrCollapsedSection extends StatefulWidget {
  const TrCollapsedSection({
    super.key,
    required this.title,
    required this.jobs,
    required this.onTap,
    this.initiallyExpanded = false,
  });
  final String title;
  final List<Job> jobs;
  final void Function(Job) onTap;
  final bool initiallyExpanded;

  @override
  State<TrCollapsedSection> createState() => _TrCollapsedSectionState();
}

class _TrCollapsedSectionState extends State<TrCollapsedSection> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: Space.s2_5,
    children: [
      Semantics(
        button: true,
        expanded: _open,
        label: '${widget.title}, ${widget.jobs.length}',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => setState(() => _open = !_open),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.tapMin),
            child: Row(
              children: [
                Expanded(
                  child: TrSectionLabel(
                    widget.title,
                    count: widget.jobs.length,
                  ),
                ),
                const SizedBox(width: Space.s2),
                THIcon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  tone: THTone.soft,
                ),
              ],
            ),
          ),
        ),
      ),
      if (_open) TrJobCards(jobs: widget.jobs, onTap: widget.onTap),
    ],
  );
}

/// Confirm sheet shown when going offline with leads or booked work.
/// Resolves true only on "Go offline". The sheet route sits above the
/// screen's [ThScope], so it re-applies the scope itself.
Future<bool> showTrGoOfflineSheet(
  BuildContext context, {
  required ThemeMode themeMode,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        ThScope(themeMode: themeMode, child: const _TrGoOfflineSheet()),
  );
  return result ?? false;
}

class _TrGoOfflineSheet extends StatelessWidget {
  const _TrGoOfflineSheet();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.th.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(Radii.sheet),
      ),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const THText('Go offline?', style: THTextStyle.h2),
            const SizedBox(height: Space.s2),
            const THText(
              'You have active or booked jobs. Going offline means no new '
              'leads, but your current jobs are unaffected.',
              style: THTextStyle.body,
              tone: THTone.soft,
            ),
            const SizedBox(height: Space.s5),
            Row(
              spacing: Space.s3,
              children: [
                Expanded(
                  child: THButton(
                    label: 'Cancel',
                    kind: THButtonKind.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                Expanded(
                  child: THButton(
                    label: 'Go offline',
                    onPressed: () => Navigator.of(context).pop(true),
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
