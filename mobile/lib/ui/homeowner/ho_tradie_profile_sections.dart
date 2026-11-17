import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'ho_tradie_profile_mapper.dart';
import 'ho_tradie_profile_providers.dart';

class ThProfileRateCard extends StatelessWidget {
  const ThProfileRateCard({super.key, required this.entry});

  final TradieListEntry? entry;

  @override
  Widget build(BuildContext context) {
    final label = thRateLabel(entry);
    if (label == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ThProfileSectionLabel('SERVICES AND RATES'),
        const SizedBox(height: Space.s2),
        THCard(
          children: [
            THKeyValue('For this job', label, bold: true),
            const SizedBox(height: Space.s1),
            const THText(
              'Rate is locked when you request.',
              style: THTextStyle.meta,
              tone: THTone.soft,
            ),
          ],
        ),
      ],
    );
  }
}

class ThProfileTrustCard extends StatelessWidget {
  const ThProfileTrustCard({super.key, required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    if (!thHasTrustDetails(profile)) return const SizedBox.shrink();
    final verified = profile?.isVerified == true;
    final insured = profile?.hasInsurance == true;
    final registration = thProfileRegistration(profile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ThProfileSectionLabel('LICENCES AND INSURANCE'),
        const SizedBox(height: Space.s2),
        THCard(
          children: [
            if (verified)
              const THKeyValue(
                'Identity check',
                'Verified',
                badge: THBadgeKind.ok,
              ),
            if (insured)
              THKeyValue(
                'Public liability',
                'Current',
                badge: THBadgeKind.ok,
                divider: verified,
              ),
            if (registration != null)
              THKeyValue(
                'NZ registration',
                '#$registration',
                badge: THBadgeKind.brand,
                divider: verified || insured,
              ),
          ],
        ),
      ],
    );
  }
}

class ThProfileAboutCard extends StatelessWidget {
  const ThProfileAboutCard({super.key, required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final bio = profile?.bio?.trim() ?? '';
    if (bio.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const THText(
          'ABOUT',
          key: Key('profile_about_eyebrow'),
          style: THTextStyle.label,
          tone: THTone.soft,
        ),
        const SizedBox(height: Space.s2),
        THCard(
          children: [
            THText(
              bio,
              key: const Key('profile_about_body'),
              style: THTextStyle.body,
            ),
          ],
        ),
      ],
    );
  }
}

class ThProfileReviews extends StatelessWidget {
  const ThProfileReviews({
    super.key,
    required this.state,
    required this.onLoadMore,
  });

  final ThReviewsState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ThProfileSectionLabel('RECENT REVIEWS'),
        const SizedBox(height: Space.s2),
        if (state.reviews.isEmpty && state.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(Space.s6),
              child: CircularProgressIndicator(),
            ),
          )
        else if (state.reviews.isEmpty && !state.hasError)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.s4),
            child: THText(
              'No reviews yet — reviews appear here after a completed job.',
              style: THTextStyle.body,
              tone: THTone.soft,
              align: TextAlign.center,
            ),
          )
        else ...[
          for (final review in state.reviews)
            ThProfileReviewCard(review: review),
          if (state.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(Space.s3),
                child: CircularProgressIndicator(),
              ),
            ),
          if (!state.hasMore && state.reviews.isNotEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(Space.s3),
                child: THText(
                  'All reviews loaded',
                  style: THTextStyle.meta,
                  tone: THTone.soft,
                ),
              ),
            ),
        ],
        if (state.hasError)
          Align(
            alignment: Alignment.centerLeft,
            child: THButton(
              label: 'Could not load reviews. Try again.',
              kind: THButtonKind.ghost,
              size: THButtonSize.sm,
              fullWidth: false,
              onPressed: onLoadMore,
            ),
          ),
      ],
    );
  }
}

class ThProfileReviewCard extends StatelessWidget {
  const ThProfileReviewCard({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final comment = review.comment?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: THCard(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Space.s2,
            children: [
              Expanded(
                child: THText(
                  review.reviewerName.isNotEmpty
                      ? review.reviewerName
                      : 'Anonymous',
                  style: THTextStyle.title,
                ),
              ),
              THText(
                review.relativeDate,
                style: THTextStyle.meta,
                tone: THTone.soft,
              ),
            ],
          ),
          const SizedBox(height: Space.s1),
          Align(alignment: Alignment.centerLeft, child: THStars(review.rating)),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: Space.s1_5),
            THText(comment, style: THTextStyle.body),
          ],
        ],
      ),
    );
  }
}

class ThProfileSectionLabel extends StatelessWidget {
  const ThProfileSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      THText(text, style: THTextStyle.label, tone: THTone.soft);
}
