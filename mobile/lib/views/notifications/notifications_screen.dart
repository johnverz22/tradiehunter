import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/notification_center.dart';
import '../../widgets/th_components.dart';
import '../states/designed_empty_state.dart';

/// H20 Notifications (v1.6.2 frames-homeowner.html).
///
/// Fed by the real FCM stream via [notificationCenterProvider] — the
/// foreground/background handlers in main.dart record every push here.
/// Filter chips mirror the mockup: All / Jobs / Payments / Reminders.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = 'All';

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
    final th = Theme.of(context).extension<THColors>()!;
    final center = ref.watch(notificationCenterProvider);
    final all = center.items;
    final visible = _filter == 'All'
        ? all
        : all
              .where(
                (n) =>
                    _categoryLabel(n.category).toLowerCase() ==
                    _filter.toLowerCase(),
              )
              .toList();

    return Scaffold(
      backgroundColor: th.paper,
      appBar: AppBar(
        backgroundColor: th.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: th.text),
        title: Text(
          'Notifications',
          style: THType.section.copyWith(color: th.text),
        ),
        actions: [
          if (all.isNotEmpty && center.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationCenterProvider.notifier).markAllRead(),
              child: Text(
                'Mark read',
                style: THType.secondaryW600.copyWith(color: th.textBrand),
              ),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: all.isEmpty
            ? const DesignedEmptyState(variant: DesignedStateVariant.noMessages)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.s3,
                      Space.gutter,
                      Space.s1,
                    ),
                    child: SizedBox(
                      height: Sizes.tapMin,
                      child: THFadeRow(
                        fadeWidth: Space.s7,
                        children: [
                          for (final f in _filters)
                            GestureDetector(
                              onTap: () => setState(() => _filter = f),
                              child: THFilterChip(
                                label: f,
                                selected: _filter == f,
                                outlined: f != 'All',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: visible.isEmpty
                        ? Center(
                            child: Text(
                              'No $_filter notifications',
                              style: THType.secondary.copyWith(
                                color: th.textSoft,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              Space.gutter,
                              Space.s2,
                              Space.gutter,
                              Space.navClearance,
                            ),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: Space.s2),
                            itemBuilder: (_, i) {
                              final n = visible[i];
                              final unread = center.isUnread(n);
                              return _NotificationRow(
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
                                            notificationCenterProvider.notifier,
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
  }
}

/// One notification row — icon tile + title/body + time + unread dot.
class _NotificationRow extends StatelessWidget {
  final IconData icon;
  final String category;
  final String title;
  final String? body;
  final String time;
  final bool unread;
  final VoidCallback? onTap;

  const _NotificationRow({
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
    final th = Theme.of(context).extension<THColors>()!;
    return Semantics(
      button: true,
      label: 'Notification: $title',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: Container(
          padding: const EdgeInsets.all(Space.s4),
          decoration: BoxDecoration(
            color: unread ? th.tintBrand : th.surface,
            borderRadius: BorderRadius.circular(Radii.tile),
            border: Border.all(color: th.line, width: Sizes.borderWidthHair),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: Sizes.avatarMd,
                height: Sizes.avatarMd,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: th.tintBrand,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: Sizes.iconMd, color: th.textBrand),
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
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: THType.cardTitle.copyWith(color: th.text),
                          ),
                        ),
                        Text(
                          time,
                          style: THType.caption.copyWith(color: th.textSoft),
                        ),
                      ],
                    ),
                    if (body != null && body!.isNotEmpty) ...[
                      const SizedBox(height: Space.s0_5),
                      Text(
                        body!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: THType.secondary.copyWith(color: th.textSoft),
                      ),
                    ],
                    const SizedBox(height: Space.s1),
                    Text(
                      category,
                      style: THType.caption.copyWith(color: th.textBrand),
                    ),
                  ],
                ),
              ),
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(left: Space.s2),
                  child: Container(
                    width: Sizes.dot,
                    height: Sizes.dot,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: th.brand,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
