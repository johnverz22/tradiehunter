import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/marketplace.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../widgets/fixo_cards.dart';
import '../../widgets/tradie_widgets.dart';
import '../../widgets/schedule_sheet.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String jobId;
  const ChatScreen({super.key, required this.jobId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    // Older messages live at the top — paginate when near min extent.
    if (_scrollCtrl.position.pixels <=
        _scrollCtrl.position.minScrollExtent + 50) {
      ref.read(chatNotifierProvider(widget.jobId).notifier).loadMore();
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    await ref.read(chatNotifierProvider(widget.jobId).notifier).sendMessage(text);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final chatState = ref.watch(chatNotifierProvider(widget.jobId));
    final jobsState = ref.watch(jobsViewModelProvider);
    final job = jobsState.jobs.cast<Job?>().firstWhere(
        (j) => j?.id == widget.jobId, orElse: () => null);

    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const FixoAvatar(initials: 'D', radius: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job?.title ?? 'Chat',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                Text(job?.category ?? 'Tradie',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w400)),
              ],
            ),
          ],
        ),
        actions: [
          // Schedule button (M4-08) — available for Confirmed jobs.
          if (job?.status == 'Confirmed' || job?.status == 'InProgress')
            IconButton(
              tooltip: 'Schedule',
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: () => ScheduleSheet.show(
                context,
                jobId: widget.jobId,
              ),
            ),
          IconButton(
            tooltip: 'Call tradie',
            icon: Icon(Icons.phone_outlined,
                color: DesignTokens.brand500),
            // TODO(backend): tel: link from GET /api/users/:id.
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calling — coming soon'))),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? DesignTokens.cardDark : Colors.white,
              border: Border(
                  bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: JobStepper(activeStage: job?.stage ?? 2),
          ),
          Expanded(
            child: chatState.isLoading && chatState.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    children: [
                      if (chatState.hasMore)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      const SizedBox(height: 12),
                      for (final m in chatState.messages)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: m.sentByMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: m.sentByMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!m.sentByMe && m.senderName.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                                    child: Text(
                                      m.senderName,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                Container(
                                  constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: m.sentByMe
                                        ? DesignTokens.brand500
                                        : (isDark
                                            ? DesignTokens.cardDark
                                            : DesignTokens.brand100Light),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(12),
                                      topRight: const Radius.circular(12),
                                      bottomLeft: Radius.circular(m.sentByMe ? 12 : 2),
                                      bottomRight: Radius.circular(m.sentByMe ? 2 : 12),
                                    ),
                                    border: m.sentByMe
                                        ? null
                                        : Border.all(
                                            color: isDark
                                                ? DesignTokens.paperLineDark
                                                : DesignTokens.paperLineLight),
                                  ),
                                  child: Text(
                                    m.text ?? '',
                                    style: TextStyle(
                                        color: m.sentByMe
                                            ? Colors.white
                                            : theme.colorScheme.onSurface),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
                                  child: Text(
                                    timeFormat.format(m.sentAtUtc.toLocal()),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
              decoration: BoxDecoration(
                color: isDark ? DesignTokens.cardDark : Colors.white,
                border:
                    Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach photo',
                    // TODO(backend): attach photo via POST /api/uploads.
                    onPressed: () => ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                            content:
                                Text('Photo attach — coming soon'))),
                    icon: const Icon(Icons.camera_alt_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: const InputDecoration(
                          hintText: 'Type a message…'),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: DesignTokens.amber,
                    ),
                    child: IconButton(
                      tooltip: 'Send message',
                      onPressed: _send,
                      icon: const Icon(Icons.send,
                          size: 20, color: DesignTokens.onAmber),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
