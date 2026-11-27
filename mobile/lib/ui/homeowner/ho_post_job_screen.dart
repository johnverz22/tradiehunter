import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'ho_post_job_address.dart';
import 'ho_post_job_basics.dart';
import 'ho_post_job_mapper.dart';
import 'ho_post_job_photos.dart';
import 'ho_post_job_project.dart';
import 'ho_post_job_review.dart';
import 'ho_post_job_timing.dart';

/// v2 Post a Job screen. One route, two states: Quick job (hourly) and
/// Project, switched through `postJobProvider.jobType` (plan 4.1 #3).
class ThPostJobScreen extends ConsumerWidget {
  const ThPostJobScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.read(profileViewModelProvider).profile?['role'];
    final isTradie = role == 1 || role == 'Tradie';
    if (isTradie) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/tradie');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final state = ref.watch(postJobProvider);
    final copy = thPostJobCopy(state.jobType, openToBoard: state.openToBoard);
    final missing = thMissingFieldHelper(state);
    final canSubmit =
        !state.isSubmitting && (state.submittedJobId != null || state.isValid);

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          return THScaffold(
            key: const Key('post_job_screen'),
            appBar: THAppBar(title: 'Post a Job', subtitle: copy.subtitle),
            body: AbsorbPointer(
              absorbing: state.isSubmitting || state.submittedJobId != null,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Field order follows the mockup (`ho_post_quick`,
                      // `ho_post_project`); kept extras follow in a labelled
                      // "More details" group (fix plan H-05).
                      const HoPostJobBasics(),
                      if (state.isProject) ...[
                        const SizedBox(height: Space.s6),
                        const HoPostJobProject(),
                      ],
                      const SizedBox(height: Space.s6),
                      const HoPostJobTiming(),
                      const SizedBox(height: Space.s5),
                      const HoPostJobHours(),
                      const SizedBox(height: Space.s6),
                      const HoPostJobAddress(),
                      const SizedBox(height: Space.s6),
                      const HoPostJobPhotos(),
                      const SizedBox(height: Space.s6),
                      Semantics(
                        header: true,
                        child: THText(
                          'MORE DETAILS',
                          style: THTextStyle.label,
                          tone: THTone.soft,
                        ),
                      ),
                      const SizedBox(height: Space.s3),
                      const HoPostJobUrgency(),
                      const SizedBox(height: Space.s6),
                      THText(
                        'REVIEW YOUR JOB',
                        style: THTextStyle.label,
                        tone: THTone.soft,
                      ),
                      const SizedBox(height: Space.s2),
                      HoPostJobReviewCard(state: state),
                      if (state.error != null &&
                          !state.error!.contains('description'))
                        Padding(
                          padding: const EdgeInsets.only(top: Space.s4),
                          child: THText(
                            state.error!,
                            style: THTextStyle.meta,
                            tone: THTone.danger,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            stickyBar: THStickyBar(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    THButton(
                      key: const Key('post_job_button'),
                      label: state.submittedJobId == null
                          ? copy.buttonLabel
                          : 'Retry photo upload',
                      kind: THButtonKind.accent,
                      loading: state.isSubmitting,
                      onPressed: canSubmit ? () => _submit(context, ref) : null,
                    ),
                    if (missing != null) ...[
                      const SizedBox(height: Space.s2),
                      THText(
                        missing,
                        style: THTextStyle.meta,
                        tone: THTone.soft,
                        align: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _submit(BuildContext context, WidgetRef ref) {
    unawaited(_submitFlow(context, ref));
  }

  Future<void> _submitFlow(BuildContext context, WidgetRef ref) async {
    final state = ref.read(postJobProvider);
    final jobId = await ref.read(postJobProvider.notifier).submit();
    if (jobId != null && context.mounted) {
      if (state.isProject && state.openToBoard) {
        context.push('/jobs/$jobId/quotes');
      } else {
        context.push('/jobs/$jobId/tradies');
      }
    }
  }
}
