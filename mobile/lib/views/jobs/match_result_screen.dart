import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/tradie_widgets.dart';

/// Mockup 08-match-result: "Match Found!" + tradie card,
/// amber Request + ghost See More.
/// TODO(backend): GET /api/jobs/:id/matches; POST /api/jobs/:id/requests.
class MatchResultScreen extends ConsumerStatefulWidget {
  final String jobId;
  const MatchResultScreen({super.key, required this.jobId});

  @override
  ConsumerState<MatchResultScreen> createState() => _MatchResultScreenState();
}

class _MatchResultScreenState extends ConsumerState<MatchResultScreen> {
  bool _loading = true;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref
          .read(jobsRepositoryProvider)
          .getMatches(widget.jobId);
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _request() async {
    setState(() => _requesting = true);
    await ref
        .read(jobsRepositoryProvider)
        .requestTradie(widget.jobId, 't-david');
    setState(() => _requesting = false);
    if (mounted) context.push('/chat/${widget.jobId}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Center(
                  child: Text('Match Found!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: DesignTokens.brand500)),
                ),
                const SizedBox(height: 20),
                // TODO(backend): render real matches list, not stub.
                const TradieCard(
                  initials: 'DW',
                  name: 'David Wiremu',
                  trade: 'Master Plumber',
                  verified: true,
                  distance: '1.2 km away',
                  rating: 4.9,
                  reviewCount: 124,
                  bio:
                      'Licensed plumber with 12 years experience across central Auckland. Upfront pricing, same-day service.',
                ),
                const SizedBox(height: 24),
                FixoPrimaryButton(
                    label: 'Request David',
                    isLoading: _requesting,
                    onPressed: _request),
                const SizedBox(height: 8),
                FixoGhostButton(
                  label: 'See More Matches',
                  // TODO(backend): GET /api/jobs/:id/matches (full list).
                  onPressed: () => ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(
                          content: Text('More matches — coming soon'))),
                ),
              ],
            ),
    );
  }
}
