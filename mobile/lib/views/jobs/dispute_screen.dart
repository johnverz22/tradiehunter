import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/design_tokens.dart';
import '../../viewmodels/dispute_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../widgets/sticky_action_bar.dart';
import '../widgets/fixo_feedback.dart';
import '../../feedback/fixo_notice.dart';


/// Dispute form (P7-01).
///
/// Both parties reach this from the job detail overflow. Reason is a small
/// fixed set (the values are stored verbatim as the dispute's open reason,
/// so they stay short and categorical); the story itself goes in Details,
/// which the server accepts up to 4,000 characters as text evidence.
class DisputeScreen extends ConsumerWidget {
  final String jobId;

  const DisputeScreen({super.key, required this.jobId});

  /// Reason choices sent to `POST /api/disputes` verbatim.
  static const reasons = [
    'Poor Quality',
    'Damage to Property',
    'Overcharged',
    'Other',
  ];

  /// Server limit for a text-evidence item (`AddEvidenceTextRequest`).
  static const maxDetailsLength = 4000;

  /// Client-side photo cap for one evidence upload batch.
  static const maxPhotos = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(disputeProvider);
    final notifier = ref.read(disputeProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: const Key('dispute_screen'),
      appBar: const FixoAppBar(title: 'Open dispute'),
      body: ListView(
        padding: FixoPadding.page,
        children: [
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s4),
              child: FixoInfoBanner.error(message: state.error!),
            ),

          // ── Reason ────────────────────────────────────────────────────
          Text('What went wrong?', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.s2),
          FixoCard(
            padding: const EdgeInsets.symmetric(vertical: Space.s1),
            child: RadioGroup<String>(
              groupValue: state.reason,
              onChanged: (val) {
                if (val != null) notifier.setReason(val);
              },
              child: Column(
                children: [
                  for (final reason in reasons)
                    RadioListTile<String>(
                      key: Key('dispute_reason_$reason'),
                      title: Text(reason),
                      value: reason,
                      activeColor: DesignTokens.brand500,
                      contentPadding: const EdgeInsets.symmetric(horizontal: Space.s3),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.s6),

          // ── Details ───────────────────────────────────────────────────
          Text('Tell us what happened', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.s2),
          TextFormField(
            key: const Key('dispute_details_field'),
            maxLines: 5,
            maxLength: maxDetailsLength,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Describe the issue…',
              counterText: '',
            ),
            onChanged: notifier.setDetails,
          ),
          const SizedBox(height: Space.s1),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${state.details.length}/$maxDetailsLength',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeCaption,
                color: DesignTokens.inkSoft(isDark),
              ),
            ),
          ),
          const SizedBox(height: Space.s4),

          // ── Evidence photos ───────────────────────────────────────────
          Text(
            'Evidence photos (optional)',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Space.s2),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final path in state.photoPaths)
                _EvidenceThumb(
                  path: path,
                  index: state.photoPaths.indexOf(path),
                  onRemove: () => notifier.removePhoto(path),
                ),
              if (state.photoPaths.length < maxPhotos)
                _AddEvidenceTile(onTap: () => _pickEvidence(context, notifier)),
            ],
          ),
          const SizedBox(height: Space.s2),
          Text(
            'Up to $maxPhotos photos.',
            style: TextStyle(fontSize: DesignTokens.fontSizeCaption, color: DesignTokens.inkSoft(isDark)),
          ),

          // ── What happens next — factual, no SLA promises ──────────────
          const SizedBox(height: Space.s5),
          FixoCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: DesignTokens.brand500,
                ),
                const SizedBox(width: Space.s2_5),
                Expanded(
                  child: Text(
                    'A member of our team reviews the dispute and the evidence '
                    'from both sides. The job is marked Disputed until they '
                    'reach a decision — we will let you know in the app.',
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeSecondary,
                      height: 1.45,
                      color: DesignTokens.inkSoft(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        child: FixoPrimaryButton(
          key: const Key('open_dispute_button'),
          label: 'Submit dispute',
          isLoading: state.isSubmitting,
          onPressed: () async {
            final success = await notifier.submitDispute(jobId);
            if (success && context.mounted) {
              FixoNotice.success(context, 'Dispute submitted for review.');
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/jobs/$jobId/detail');
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _pickEvidence(
    BuildContext context,
    DisputeNotifier notifier,
  ) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 90,
      );
      if (photo != null && context.mounted) {
        notifier.addPhoto(photo.path);
      }
    } catch (_) {
      if (context.mounted) {
        FixoNotice.error(context, 'Could not open photos. Try again.');
      }
    }
  }
}

/// A picked evidence photo with a real 48px remove control — the pre-submit
/// list is editable; nothing here deletes server-side evidence.
class _EvidenceThumb extends StatelessWidget {
  final String path;
  final int index;
  final VoidCallback onRemove;

  const _EvidenceThumb({
    required this.path,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: DesignTokens.surfaceStatus(
                Theme.of(context).brightness == Brightness.dark,
              ),
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Semantics(
            button: true,
            label: 'Remove photo ${index + 1}',
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.all(Space.s1),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: Alpha.fillDark),
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddEvidenceTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddEvidenceTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'Add evidence photo',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
            border: Border.all(
              color: isDark
                  ? DesignTokens.paperLineDark
                  : DesignTokens.paperLineLight,
            ),
            color: DesignTokens.surfaceStatus(isDark),
          ),
          child: Icon(
            Icons.add_a_photo_outlined,
            color: DesignTokens.inkSoft(isDark),
          ),
        ),
      ),
    );
  }
}
