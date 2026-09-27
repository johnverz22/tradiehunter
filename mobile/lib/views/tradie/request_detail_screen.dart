import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';

/// Mockup 10-request-detail (tradie): map placeholder, title + URGENT,
/// info grid, description, photo strip, Decline / Accept bar.
/// TODO(backend): GET /api/jobs/:id; POST accept/decline → SignalR + FCM.
class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() call) async {
    setState(() => _busy = true);
    await call();
    setState(() => _busy = false);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = ref.watch(jobsRepositoryProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Request')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: isDark
                  ? DesignTokens.brand100Dark
                  : DesignTokens.brand100Light,
              borderRadius:
                  BorderRadius.circular(DesignTokens.radius),
            ),
            alignment: Alignment.center,
            // TODO(backend): real map preview from job geo.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined,
                    color: DesignTokens.brand500, size: 20),
                const SizedBox(width: 6),
                Text('Ponsonby',
                    style: TextStyle(
                        color: DesignTokens.brand500,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text('Emergency Pipe Burst',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const StatusBadge(
                  label: 'URGENT', kind: FixoBadgeKind.urgent),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(
                  child: _Info(label: 'Distance', value: '3.5 km')),
              Expanded(
                  child: _Info(label: 'Client', value: 'Sarah H. (★5.0)')),
              Expanded(
                  child: _Info(label: 'Posted', value: '10 mins ago')),
            ],
          ),
          const Divider(height: 32),
          Text(
            'Water gushing under the kitchen sink since this morning. Needs urgent attention — water turned off at the mains.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              // TODO(backend): photoUrls from GET /api/jobs/:id.
              itemBuilder: (_, i) => Container(
                width: 120,
                decoration: BoxDecoration(
                  color: isDark
                      ? DesignTokens.brand100Dark
                      : DesignTokens.brand100Light,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radius),
                ),
                alignment: Alignment.center,
                child: Text('Photo ${i + 1}',
                    style: TextStyle(
                        fontSize: 12, color: DesignTokens.brand500)),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: FixoGhostButton(
                  label: 'Decline',
                  onPressed: _busy
                      ? null
                      : () => _act(
                          () => repo.declineJob(widget.requestId)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FixoPrimaryButton(
                  label: 'Accept Job',
                  isLoading: _busy,
                  onPressed: () =>
                      _act(() => repo.acceptJob(widget.requestId)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  const _Info({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
