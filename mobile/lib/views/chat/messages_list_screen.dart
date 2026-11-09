import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_states.dart';
import '../widgets/chat_widgets.dart';
import 'chat_screen.dart';

/// Messages inbox — rows push to /chat/:jobId.
///
/// Backed by GET /api/chat/conversations (V15-16): one call returns
/// participant-first summaries with a real last-message preview and a real
/// unread count — no per-job history waterfall and no invented badges.
class MessagesListScreen extends ConsumerStatefulWidget {
  const MessagesListScreen({super.key});

  @override
  ConsumerState<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends ConsumerState<MessagesListScreen> {
  bool _loading = true;
  String? _error;
  List<ConversationSummary> _conversations = const [];
  String? _selectedJobId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summaries = await ref
          .read(chatRepositoryProvider)
          .getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = summaries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load conversations.';
        _loading = false;
      });
    }
  }

  Future<void> _open(String jobId) async {
    // Reload on return — reading the thread clears its unread badge.
    await context.push('/chat/$jobId');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    const appBar = FixoAppBar(title: 'Messages', showBack: false);

    if (_loading && _conversations.isEmpty) {
      return const Scaffold(appBar: appBar, body: FixoLoading());
    }

    if (_error != null && _conversations.isEmpty) {
      return Scaffold(
        appBar: appBar,
        body: FixoErrorState(message: _error!, onRetry: _load),
      );
    }

    if (_conversations.isEmpty) {
      return const Scaffold(
        appBar: appBar,
        body: FixoEmptyState(
          icon: Icons.chat_bubble_outline,
          title: 'No messages yet',
          subtitle: 'Once a job is matched, your chats will show up here.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kBreakpointMasterDetail;

        final masterList = RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.navClearance),
            itemCount: _conversations.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.s1),
            itemBuilder: (_, i) {
              final c = _conversations[i];
              return ConversationTile(
                conversation: c,
                selected: isWide && _selectedJobId == c.jobId,
                onTap: isWide
                    ? () => setState(() => _selectedJobId = c.jobId)
                    : () => _open(c.jobId),
              );
            },
          ),
        );

        final detailPanel = _selectedJobId != null
            ? ChatScreen(
                key: ValueKey('chat_$_selectedJobId'),
                jobId: _selectedJobId!,
                embedded: true,
              )
            : null;

        return Scaffold(
          appBar: appBar,
          body: MasterDetailLayout(
            master: masterList,
            detail: detailPanel ?? const SizedBox.shrink(),
            detailVisible: _selectedJobId != null,
            emptyDetail: const _MessagesEmptyDetail(),
          ),
        );
      },
    );
  }
}

class _MessagesEmptyDetail extends StatelessWidget {
  const _MessagesEmptyDetail();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: isDark
                  ? DesignTokens.inkSoftDark
                  : DesignTokens.inkSoftLight,
            ),
            const SizedBox(height: Space.s4),
            Text(
              'Select a conversation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FW.semibold,
                color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
              ),
            ),
            const SizedBox(height: Space.s1_5),
            Text(
              'Choose a chat from the left panel to view messages.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: DesignTokens.inkSoft(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
