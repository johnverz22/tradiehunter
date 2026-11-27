import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/auth_viewmodel.dart' show resolveBaseUrl;
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import '../feedback/th_state_view.dart';
import '../homeowner/ho_quotes_screen.dart' show thQuotesCloseLabel;
import 'tr_available_jobs_screen.dart';
import 'tr_photo_viewer.dart';
import 'tr_quote_sheet.dart';

/// Tradie open-project detail screen (plan 10 Q7.10, `tr_job_board_detail`).
/// Shows full D7 details (scope, notes, budget, materials, site visit, timing,
/// all photos, suburb & distance) and submits a quote via [showTrQuoteSheet].
class TrJobBoardDetailScreen extends ConsumerStatefulWidget {
  const TrJobBoardDetailScreen({
    super.key,
    required this.jobId,
    this.initialJob,
  });

  final String jobId;
  final AvailableJob? initialJob;

  static const String route = '/tradie/available-jobs/:jobId';

  @override
  ConsumerState<TrJobBoardDetailScreen> createState() =>
      _TrJobBoardDetailScreenState();
}

class _TrJobBoardDetailScreenState
    extends ConsumerState<TrJobBoardDetailScreen> {
  bool _busy = false;
  bool _quoted = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialJob == null) {
      Future.microtask(() {
        if (mounted) ref.read(availableJobsProvider.notifier).load();
      });
    }
  }

  AvailableJob? _resolveJob(AvailableJobsState boardState) {
    if (widget.initialJob != null) return widget.initialJob;
    for (final j in boardState.jobs) {
      if (j.id == widget.jobId) return j;
    }
    return null;
  }

  Future<void> _submitQuote(AvailableJob job) async {
    if (_busy || _quoted) return;
    final profile = ref.read(profileViewModelProvider).profile;
    final gstRaw = profile?['isGstRegistered'];
    final gstRegistered = gstRaw is bool ? gstRaw : null;

    final payload = await showTrQuoteSheet(
      context,
      themeMode: ref.read(themeModeProvider),
      gstRegisteredFromProfile: gstRegistered,
      quoteValidityHours: job.quoteValidityHours,
    );
    if (payload == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(quotesProvider(job.id).notifier)
          .submitQuote(payload);
      if (!mounted) return;
      ref.read(availableJobsProvider.notifier).removeJob(job.id);
      setState(() {
        _busy = false;
        _quoted = true;
      });
      THNotice.success(context, 'Quote submitted to the homeowner.');
      context.pop();
    } on ProfileApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      THNotice.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      THNotice.error(context, 'Could not submit quote. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardState = ref.watch(availableJobsProvider);
    final job = _resolveJob(boardState);

    if (job == null) {
      return ThScope(
        themeMode: ref.watch(themeModeProvider),
        child: THScaffold(
          appBar: const THAppBar(title: 'Open project'),
          scrollable: false,
          body: boardState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ThStateView.error(
                  message: boardState.error ??
                      'This project is no longer available on the board.',
                  onRetry: () => ref.read(availableJobsProvider.notifier).load(),
                ),
        ),
      );
    }

    final closeLabel = thQuotesCloseLabel(job.quotesCloseAtUtc) ?? '';
    final closeShort = closeLabel.replaceFirst('Quotes close in ', '');
    final quotesLabel = thBoardQuotesCountLabel(job.quotesReceived);

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: THScaffold(
        key: const Key('tr_job_board_detail_screen'),
        appBar: THAppBar(
          title: 'Open project',
          subtitle: '${thBoardCloseBadge(job.quotesCloseAtUtc)} · $quotesLabel',
        ),
        stickyBar: THStickyBar(
          children: [
            Expanded(
              child: THButton(
                key: const Key('board_submit_quote_button'),
                label: _quoted ? 'Quote submitted' : 'Submit quote',
                kind: THButtonKind.accent,
                loading: _busy,
                onPressed: (_busy || _quoted) ? null : () => _submitQuote(job),
              ),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            THHero(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: THText(
                        'QUOTES CLOSE IN',
                        style: THTextStyle.label,
                        tone: THTone.gold,
                      ),
                    ),
                    const THBadge('Open project', kind: THBadgeKind.glass),
                  ],
                ),
                const SizedBox(height: Space.s1_5),
                THText(
                  closeShort,
                  style: THTextStyle.moneyLg,
                  tone: THTone.onHero,
                ),
                if (job.quoteValidityHours != null) ...[
                  const SizedBox(height: Space.s1),
                  THText(
                    'Quote valid for ${job.quoteValidityHours} hours once submitted.',
                    style: THTextStyle.meta,
                    tone: THTone.onHeroSoft,
                  ),
                ],
              ],
            ),
            const SizedBox(height: Space.s4),
            THCard(
              padding: Space.s4,
              children: [
                Wrap(
                  spacing: Space.s1_5,
                  runSpacing: Space.s1_5,
                  children: [
                    THBadge(job.category, kind: THBadgeKind.brand),
                    THBadge(
                      thBoardTimingLabel(job.timingPreference),
                      kind: THBadgeKind.accent,
                      icon: Icons.calendar_today_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: Space.s2_5),
                THText(job.title, style: THTextStyle.h2),
                const SizedBox(height: Space.s1_5),
                THText(
                  job.description.isNotEmpty
                      ? job.description
                      : 'No description provided.',
                  style: THTextStyle.body,
                  tone: THTone.soft,
                ),
              ],
            ),
            if (job.photoUrls.isNotEmpty) ...[
              const SizedBox(height: Space.s4),
              const THText('Photos from the homeowner', style: THTextStyle.title),
              const SizedBox(height: Space.s2),
              TrPhotoStrip(
                photoUrls: job.photoUrls,
                baseUrl: resolveBaseUrl(),
                onOpen: (i) => showTrPhotoViewer(
                  context,
                  photoUrls: job.photoUrls,
                  baseUrl: resolveBaseUrl(),
                  initialIndex: i,
                ),
              ),
            ],
            const SizedBox(height: Space.s4),
            const THText('Location', style: THTextStyle.title),
            const SizedBox(height: Space.s2),
            THCard(
              padding: Space.s4,
              children: [
                THKeyValue(
                  'Suburb',
                  job.suburb?.isNotEmpty == true ? job.suburb! : 'Nearby',
                  bold: true,
                ),
                if (job.distanceKm != null)
                  THKeyValue(
                    'Distance',
                    '${job.distanceKm!.toStringAsFixed(1)} km away',
                    bold: true,
                    divider: true,
                  ),
                const THKeyValue(
                  'Exact address',
                  'Shared after you are booked',
                  badge: THBadgeKind.brand,
                  divider: true,
                ),
              ],
            ),
            const SizedBox(height: Space.s4),
            const THText('Project scope and budget', style: THTextStyle.title),
            const SizedBox(height: Space.s2),
            THCard(
              padding: Space.s4,
              children: [
                THKeyValue(
                  'Budget range',
                  thBoardBudgetLabel(job.budgetMin, job.budgetMax),
                  bold: true,
                ),
                THKeyValue(
                  'Materials',
                  thBoardMaterialsLabel(job.materialsBy),
                  bold: true,
                  divider: true,
                ),
                THKeyValue(
                  'Site visit',
                  job.siteVisitWelcome
                      ? 'Welcome before quoting'
                      : 'Not requested',
                  bold: true,
                  divider: true,
                ),
                if (job.scopeNotes?.trim().isNotEmpty == true)
                  THKeyValue(
                    'Scope notes',
                    job.scopeNotes!.trim(),
                    bold: true,
                    divider: true,
                  ),
                THKeyValue(
                  'Preferred timing',
                  thBoardTimingLabel(job.timingPreference),
                  bold: true,
                  divider: true,
                ),
              ],
            ),
            const SizedBox(height: Space.s4),
            const THCard(
              padding: Space.s3_5,
              children: [
                THText(
                  'Your quote stays binding once submitted. Any extra costs later require homeowner approval.',
                  style: THTextStyle.meta,
                  tone: THTone.soft,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
