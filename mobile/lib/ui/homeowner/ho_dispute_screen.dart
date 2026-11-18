import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../feedback/th_notice.dart';
import '../../models/marketplace.dart';
import '../../viewmodels/dispute_viewmodel.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../shared/th_choice_pills.dart';

/// Fetches the job title for the dispute header subtitle if available.
final disputeJobProvider = FutureProvider.autoDispose.family<Job?, String>((
  ref,
  jobId,
) async {
  try {
    return await ref.read(jobsRepositoryProvider).getJobById(jobId);
  } catch (_) {
    return null;
  }
});

/// v2 presentation of the manual dispute and evidence submission flow.
class HoDisputeScreen extends ConsumerWidget {
  const HoDisputeScreen({super.key, required this.jobId});

  final String jobId;
  static const reasons = <String>[
    'Poor Quality',
    'Damage to Property',
    'Overcharged',
    'Other',
  ];
  static const maxDetailsLength = 4000;
  static const maxPhotos = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(disputeProvider);
    final notifier = ref.read(disputeProvider.notifier);
    final jobAsync = ref.watch(disputeJobProvider(jobId));
    final jobTitle = jobAsync.valueOrNull?.title;

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) => THScaffold(
          key: const Key('dispute_screen'),
          appBar: THAppBar(title: 'Open dispute', subtitle: jobTitle),
          scrollable: true,
          stickyBar: THStickyBar(
            children: [
              THButton(
                key: const Key('open_dispute_button'),
                label: 'Submit dispute',
                kind: THButtonKind.danger,
                loading: state.isSubmitting,
                onPressed: state.isSubmitting
                    ? null
                    : () async {
                        final success = await notifier.submitDispute(jobId);
                        if (!context.mounted) return;
                        if (success) {
                          THNotice.success(
                            context,
                            'Dispute submitted for review.',
                          );
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            try {
                              context.go('/jobs/$jobId/detail');
                            } catch (_) {}
                          }
                        }
                      },
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.error != null) ...[
                THCard(
                  tone: THCardTone.danger,
                  children: [THText(state.error!, tone: THTone.danger)],
                ),
                const SizedBox(height: Space.s3),
              ],
              THCard(
                tone: THCardTone.accent,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Space.s2_5,
                    children: [
                      const THIcon(
                        Icons.info_outline_rounded,
                        tone: THTone.accent,
                      ),
                      const Expanded(
                        child: THText(
                          'Our team reviews the dispute and evidence from both sides. The job stays disputed until a decision is made; we will notify you in the app.',
                          style: THTextStyle.meta,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Space.s4),
              const THText(
                'WHAT’S WRONG',
                style: THTextStyle.label,
                tone: THTone.soft,
              ),
              const SizedBox(height: Space.s2),
              ThChoicePills(
                items: [
                  for (final reason in reasons)
                    ThChoicePillItem(
                      key: Key('dispute_reason_$reason'),
                      label: reason,
                      selected: state.reason == reason,
                      onSelected: () => notifier.setReason(reason),
                    ),
                ],
              ),
              const SizedBox(height: Space.s4),
              const THText(
                'TELL US WHAT HAPPENED',
                style: THTextStyle.label,
                tone: THTone.soft,
              ),
              const SizedBox(height: Space.s2),
              Container(
                decoration: BoxDecoration(
                  color: context.th.surface,
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: Border.all(color: context.th.line),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s3_5,
                  vertical: Space.s2,
                ),
                child: Semantics(
                  identifier: 'dispute_details_field',
                  child: TextField(
                    key: const Key('dispute_details_field'),
                    maxLines: 5,
                    maxLength: maxDetailsLength,
                    onChanged: notifier.setDetails,
                    style: THType.body.copyWith(color: context.th.text),
                    decoration: InputDecoration(
                      hintText: 'Describe the issue…',
                      hintStyle: THType.body.copyWith(
                        color: context.th.textSoft,
                      ),
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.s1),
              Align(
                alignment: Alignment.centerRight,
                child: THText(
                  '${state.details.length}/$maxDetailsLength',
                  style: THTextStyle.meta,
                  tone: THTone.soft,
                ),
              ),
              const SizedBox(height: Space.s4),
              const THText(
                'EVIDENCE PHOTOS (OPTIONAL)',
                style: THTextStyle.label,
                tone: THTone.soft,
              ),
              const SizedBox(height: Space.s2),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Space.s2,
                crossAxisSpacing: Space.s2,
                children: [
                  for (var i = 0; i < state.photoPaths.length; i++)
                    _EvidenceThumb(
                      path: state.photoPaths[i],
                      index: i,
                      onRemove: () => notifier.removePhoto(state.photoPaths[i]),
                    ),
                  if (state.photoPaths.length < maxPhotos)
                    _AddEvidenceTile(
                      onTap: () => _pickEvidence(context, notifier),
                    ),
                ],
              ),
              const SizedBox(height: Space.s2),
              const THText(
                'Up to 5 photos.',
                style: THTextStyle.meta,
                tone: THTone.soft,
              ),
            ],
          ),
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
        THNotice.error(context, 'Could not open photos. Try again.');
      }
    }
  }
}

class _EvidenceThumb extends StatelessWidget {
  const _EvidenceThumb({
    required this.path,
    required this.index,
    required this.onRemove,
  });
  final String path;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Radii.control),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: context.th.surfaceAlt,
            child: const THIcon(Icons.broken_image_outlined),
          ),
        ),
      ),
      Positioned(
        top: Space.s1,
        right: Space.s1,
        child: IconButton(
          tooltip: 'Remove photo ${index + 1}',
          constraints: const BoxConstraints.tightFor(
            width: Sizes.tapMin,
            height: Sizes.tapMin,
          ),
          onPressed: onRemove,
          icon: const THIcon(Icons.close_rounded, tone: THTone.danger),
        ),
      ),
    ],
  );
}

class _AddEvidenceTile extends StatelessWidget {
  const _AddEvidenceTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Add evidence photo',
    child: InkWell(
      key: const Key('dispute_evidence_add'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.control),
      child: Container(
        decoration: BoxDecoration(
          color: context.th.surface,
          border: Border.all(color: context.th.line),
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: const Center(
          child: THIcon(Icons.add_a_photo_outlined, tone: THTone.soft),
        ),
      ),
    ),
  );
}
