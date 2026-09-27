import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/fixo_cards.dart';
import '../../widgets/fixo_states.dart';
import '../../widgets/tradie_widgets.dart';

/// Messages inbox — rows push to /chat/:jobId.
/// TODO(backend): GET /api/jobs/:id/messages overview + SignalR presence.
class MessagesListScreen extends StatelessWidget {
  const MessagesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(backend): replace with real conversation list.
    const convos = [
      ('JOB-00214', 'David Wiremu', 'See you at 9am tomorrow', '9:41 AM', 2),
      ('JOB-00209', 'Aroha P.', 'Quote attached for the bedroom wall', 'Yesterday', 0),
    ];
    if (convos.isEmpty) {
      return Scaffold(
        appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Messages')),
        body: const FixoEmptyState(
          icon: Icons.chat_bubble_outline,
          title: 'No messages yet',
          subtitle: 'Your job chats will show up here.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Messages')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        itemCount: convos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final c = convos[i];
          final unread = c.$5 > 0;
          return InkWell(
            borderRadius:
                BorderRadius.circular(DesignTokens.radius),
            onTap: () => context.push('/chat/${c.$1}'),
            child: FixoCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  FixoAvatar(initials: c.$2[0]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(c.$2,
                                  style: TextStyle(
                                      fontWeight: unread
                                          ? FontWeight.w700
                                          : FontWeight.w600)),
                            ),
                            Text(c.$4,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontFamily:
                                          DesignTokens.fontMono,
                                      fontSize: 11,
                                    )),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.$3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                            if (unread)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: const BoxDecoration(
                                  color: DesignTokens.amber,
                                  shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.all(
                                      Radius.circular(100)),
                                ),
                                child: Text('${c.$5}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: DesignTokens.onAmber)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
