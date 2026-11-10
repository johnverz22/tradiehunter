// Debug-only gallery for the FixoNotice system.
//
// Registered in app_router.dart only when kDebugMode == true.
// Route: /debug/notice-gallery
//
// Lets designers and developers preview all five notice tones in both
// light and dark themes without touching the live app flows.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../feedback/fixo_notice.dart';

/// Debug-only entry point guard.  Returns null in release builds.
Widget? maybeNoticeGallery() =>
    kDebugMode ? const _NoticeGalleryScreen() : null;

class _NoticeGalleryScreen extends StatelessWidget {
  const _NoticeGalleryScreen();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<THColors>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('Notice Gallery (debug)')),
      backgroundColor: colors.paper,
      body: ListView(
        padding: FixoPadding.page,
        children: [
          _GallerySection(
            label: 'Info (3 s)',
            onTap: () => FixoNotice.info(context, NoticeCopy.copied),
          ),
          _GallerySection(
            label: 'Success (3 s)',
            onTap: () =>
                FixoNotice.success(context, NoticeCopy.profileUpdated),
          ),
          _GallerySection(
            label: 'Warning (4 s)',
            onTap: () =>
                FixoNotice.warning(context, 'Could not refresh — retrying.'),
          ),
          _GallerySection(
            label: 'Error (5 s)',
            onTap: () =>
                FixoNotice.error(context, NoticeCopy.checkInFailed),
          ),
          _GallerySection(
            label: 'Push notification (5 s)',
            onTap: () => FixoNotice.push(
              context,
              title: 'New Job Request',
              body: 'Fix leaking tap — Ponsonby',
              onView: () => debugPrint('Push action tapped'),
            ),
          ),
          _GallerySection(
            label: 'Long message (overflow check)',
            onTap: () => FixoNotice.info(
              context,
              'This is a deliberately long notice message to verify text '
              'wrapping and minimum height behaviour on narrow screens.',
            ),
          ),
        ],
      ),
    );
  }
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<THColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.text,
          side: BorderSide(color: colors.line),
          padding: const EdgeInsets.symmetric(
              horizontal: Space.s4, vertical: Space.s3_5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.control)),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label,
              style: TextStyle(
                fontFamily: TypeTokens.fontBody,
                fontSize: DesignTokens.fontSizeSm,
                fontWeight: FW.medium,
              )),
        ),
      ),
    );
  }
}
