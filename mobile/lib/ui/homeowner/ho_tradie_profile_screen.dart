import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_state_view.dart';
import 'ho_tradie_profile_actions.dart';
import 'ho_tradie_profile_header.dart';
import 'ho_tradie_profile_mapper.dart';
import 'ho_tradie_profile_providers.dart';
import 'ho_tradie_profile_sections.dart';

/// Role gate for `/tradie/:id`. The v2 screen is only safe for a homeowner
/// viewing a tradie; every other viewer keeps the v1 screen.
class ThTradieProfileRoute extends ConsumerWidget {
  const ThTradieProfileRoute({
    super.key,
    required this.profileId,
    required this.fallback,
    this.jobId,
  });

  final String profileId;
  final String? jobId;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileViewModelProvider);
    final role = profile.profile?['role'];
    if (role == 0) {
      return ThTradieProfileScreen(profileId: profileId, jobId: jobId);
    }
    if (role == null && profile.isLoading) {
      return ThScope(
        themeMode: ref.watch(themeModeProvider),
        child: Builder(
          builder: (context) => THScaffold(
            key: const Key('tradie_profile_pending'),
            appBar: const THAppBar(title: 'Profile'),
            body: const ThStateView.loading(label: 'Loading profile...'),
          ),
        ),
      );
    }
    return fallback;
  }
}

class ThTradieProfileScreen extends ConsumerWidget {
  const ThTradieProfileScreen({super.key, required this.profileId, this.jobId});

  final String profileId;
  final String? jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(thProfileProvider(profileId));
    final jobEntry = jobId != null && jobId!.isNotEmpty
        ? ref.watch(thJobTradieProvider((jobId!, profileId))).valueOrNull
        : null;
    final viewer = ref.watch(profileViewModelProvider).profile;
    final viewerId = viewer?['id']?.toString();
    final viewerRole = viewer?['role'] as int?;

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) => profileAsync.when(
          loading: () => THScaffold(
            key: const Key('ho_tradie_profile'),
            appBar: const THAppBar(title: 'Profile'),
            body: const ThStateView.loading(label: 'Loading profile...'),
          ),
          error: (_, _) => THScaffold(
            key: const Key('ho_tradie_profile'),
            appBar: const THAppBar(title: 'Profile'),
            body: ThStateView.error(
              message: 'Failed to load profile',
              onRetry: () => ref.invalidate(thProfileProvider(profileId)),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return THScaffold(
                key: const Key('ho_tradie_profile'),
                appBar: const THAppBar(title: 'Profile'),
                body: const ThStateView.empty(
                  icon: Icons.person_off_outlined,
                  title: 'Profile unavailable',
                  body: 'This profile could not be loaded.',
                ),
              );
            }
            return _ThProfileBody(
              profile: profile,
              profileId: profileId,
              jobId: jobId,
              jobEntry: jobEntry,
              viewerId: viewerId,
              viewerRole: viewerRole,
            );
          },
        ),
      ),
    );
  }
}

class _ThProfileBody extends ConsumerWidget {
  const _ThProfileBody({
    required this.profile,
    required this.profileId,
    required this.jobId,
    required this.jobEntry,
    required this.viewerId,
    required this.viewerRole,
  });

  final UserProfile profile;
  final String profileId;
  final String? jobId;
  final TradieListEntry? jobEntry;
  final String? viewerId;
  final int? viewerRole;

  bool get _canAct =>
      viewerId != null && viewerId!.isNotEmpty && viewerId != profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(thReviewsProvider(profileId));
    final reviewsNotifier = ref.read(thReviewsProvider(profileId).notifier);
    final canAct = _canAct;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          unawaited(reviewsNotifier.loadNext());
        }
        return false;
      },
      child: THScaffold(
        key: const Key('ho_tradie_profile'),
        appBar: THAppBar(
          title: 'Profile',
          actions: [
            if (canAct)
              PopupMenuButton<String>(
                tooltip: 'More actions',
                icon: const Icon(Icons.more_vert),
                iconColor: context.th.text,
                onSelected: (value) {
                  if (value == 'report') {
                    unawaited(thReportUser(context, ref, profileId));
                  } else if (value == 'block') {
                    unawaited(thBlockUser(context, ref, profileId));
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'report', child: Text('Report user')),
                  PopupMenuItem(value: 'block', child: Text('Block user')),
                ],
              ),
          ],
        ),
        stickyBar: canAct
            ? ThTradieProfileActions(
                profileId: profileId,
                isTradie: true,
                viewerRole: viewerRole,
                jobId: jobId,
                jobEntry: jobEntry,
              )
            : null,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ThProfileHeader(profile: profile, jobEntry: jobEntry),
                if (thRateLabel(jobEntry) != null) ...[
                  const SizedBox(height: Space.s5),
                  ThProfileRateCard(entry: jobEntry),
                ],
                if (thHasTrustDetails(profile)) ...[
                  const SizedBox(height: Space.s5),
                  ThProfileTrustCard(profile: profile),
                ],
                if (profile.bio?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: Space.s5),
                  ThProfileAboutCard(profile: profile),
                ],
                const SizedBox(height: Space.s5),
                ThProfileReviews(
                  state: reviews,
                  onLoadMore: () {
                    unawaited(reviewsNotifier.loadNext());
                  },
                ),
                if (canAct) ...[
                  const SizedBox(height: Space.s2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: THButton(
                      label: 'Leave a review',
                      kind: THButtonKind.ghost,
                      size: THButtonSize.sm,
                      fullWidth: false,
                      onPressed: () {
                        unawaited(
                          thLeaveReview(context, ref, profileId, viewerId!),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
