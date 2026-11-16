// ThNotificationsScreen: v2 notifications inbox (migration plan 3.3,
// id `notifications`).
//
// Hand-owned port of views/notifications/notifications_screen.dart. Same
// data source (client-side notificationCenterProvider — FCM-fed, no backend
// inbox exists), same 'Mark read' action visibility rule, same per-row
// semantics ('Notification: $title'), same unread-tap-marks-read behaviour.
// The filter chips become a token-styled THSegmented row (needs-design: no
// v2 filter mockup exists; same four filters, same filtering logic).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../widgets/notification_center.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_state_view.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';

class ThNotificationsScreen extends ConsumerStatefulWidget {
  const ThNotificationsScreen({super.key});

  @override
  ConsumerState<ThNotificationsScreen> createState() =>
      _ThNotificationsScreenState();
}

class _ThNotificationsScreenState extends ConsumerState<ThNotificationsScreen> {
  int _filterIndex = 0;

  static const _filters = ['All', 'Jobs', 'Payments', 'Reminders'];

  IconData _iconFor(String category) => switch (category) {
    'payments' => Icons.payments_outlined,
    'reminders' => Icons.schedule_outlined,
    _ => Icons.handyman_outlined, // jobs
  };

  String _categoryLabel(String category) => switch (category) {
    'payments' => 'Payments',
    'reminders' => 'Reminders',
    _ => 'Jobs',
  };

  @override
  Widget build(BuildContext context) {
    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          final c = context.th;
          final center = ref.watch(notificationCenterProvider);
          final all = center.items;
          final filter = _filters[_filterIndex];
          final visible = filter == 'All'
              ? all
              : all
                    .where(
                      (n) =>
                          _categoryLabel(n.category).toLowerCase() ==
                          filter.toLowerCase(),
                    )
                    .toList();

          return Scaffold(
            backgroundColor: c.paper,
            appBar: THAppBar(
              title: 'Notifications',
              actions: [
                if (all.isNotEmpty && center.unreadCount > 0)
                  TextButton(
                    onPressed: () => ref
                        .read(notificationCenterProvider.notifier)
                        .markAllRead(),
                    child: Text(
                      'Mark read',
                      style: THType.button.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textBrand,
                      ),
                    ),
                  ),
              ],
            ),
            body: SafeArea(
              bottom: false,
              child: all.isEmpty
                  ? Center(child: ThStateView.preset(ThStatePreset.noMessages))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Sizes.gutter,
                            Space.s3,
                            Sizes.gutter,
                            Space.s1,
                          ),
                          child: THSegmented(
                            items: _filters,
                            selected: _filterIndex,
                            onSelected: (i) => setState(() => _filterIndex = i),
                          ),
                        ),
                        Expanded(
                          child: visible.isEmpty
                              ? Center(
                                  child: Text(
                                    'No $filter notifications',
                                    style: THType.button.copyWith(
                                      color: c.textSoft,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.fromLTRB(
                                    Sizes.gutter,
                                    Space.s2,
                                    Sizes.gutter,
                                    Sizes.dockClearance,
                                  ),
                                  itemCount: visible.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: Space.s2),
                                  itemBuilder: (_, i) {
                                    final n = visible[i];
                                    final unread = center.isUnread(n);
                                    return _ThNotificationRow(
                                      icon: _iconFor(n.category),
                                      category: _categoryLabel(n.category),
                                      title: n.title,
                                      body: n.body,
                                      time: DateFormat('d MMM, h:mm a')
                                          .format(n.receivedAt),
                                      unread: unread,
                                      onTap: unread
                                          ? () => ref
                                                .read(
                                                  notificationCenterProvider
                                                      .notifier,
                                                )
                                                .markRead(n.id)
                                          : null,
                                    );
                                  },
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

/// One notification row — icon tile + title/body + time + unread dot.
class _ThNotificationRow extends StatelessWidget {
  final IconData icon;
  final String category;
  final String title;
  final String? body;
  final String time;
  final bool unread;
  final VoidCallback? onTap;

  const _ThNotificationRow({
    required this.icon,
    required this.category,
    required this.title,
    this.body,
    required this.time,
    required this.unread,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Semantics(
      button: true,
      label: 'Notification: $title',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: Container(
          padding: const EdgeInsets.all(Space.s4),
          decoration: BoxDecoration(
            color: unread ? c.tintBrand : c.surface,
            borderRadius: BorderRadius.circular(Radii.tile),
            border: Border.all(color: c.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Space.s3,
            children: [
              Container(
                width: Sizes.avatarSm,
                height: Sizes.avatarSm,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.tintBrand,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: Sizes.iconLg, color: c.textBrand),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Space.s1,
                  children: [
                    Row(
                      spacing: Space.s2,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: THType.title.copyWith(
                              fontSize: 14.5,
                              color: c.text,
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: THType.meta.copyWith(
                            fontSize: 11,
                            color: c.textSoft,
                          ),
                        ),
                      ],
                    ),
                    if (body != null && body!.isNotEmpty)
                      Text(
                        body!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: THType.meta.copyWith(color: c.textSoft),
                      ),
                    Text(
                      category,
                      style: THType.meta.copyWith(
                        fontSize: 11,
                        color: c.textBrand,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: Space.s2_5,
                  height: Space.s2_5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
