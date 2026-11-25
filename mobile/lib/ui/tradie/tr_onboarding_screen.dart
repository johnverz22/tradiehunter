import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/tradie_onboarding.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../../viewmodels/tradie_onboarding_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_state_view.dart';
import 'tr_onboarding_mapper.dart';
import 'tr_onboarding_steps.dart';

class TrOnboardingScreen extends ConsumerStatefulWidget {
  const TrOnboardingScreen({super.key});

  @override
  ConsumerState<TrOnboardingScreen> createState() => _TrOnboardingScreenState();
}

class _TrOnboardingScreenState extends ConsumerState<TrOnboardingScreen> {
  final _controllers = TrOnboardingControllers();
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(tradieOnboardingProvider.notifier).load());
  }

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  Future<void> _onContinue(
    TradieOnboardingState state,
    TradieOnboardingNotifier notifier,
  ) async {
    if (state.step < 3) {
      await notifier.saveStepAndAdvance();
      return;
    }
    final ok = await notifier.finishSetup();
    if (!ok || !mounted) return;
    ref.invalidate(profileViewModelProvider);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/tradie');
    }
  }

  Future<void> _onUploadDocument(TradieOnboardingNotifier notifier) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null) return;
    await notifier.uploadCredential(
      filePath: path,
      fileName: file.name,
      kind: CredentialKind.license,
    );
  }

  @override
  Widget build(BuildContext context) => ThScope(
        themeMode: ref.watch(themeModeProvider),
        child: Builder(builder: (ctx) => _page(ctx)),
      );

  Widget _page(BuildContext context) {
    final state = ref.watch(tradieOnboardingProvider);
    final notifier = ref.read(tradieOnboardingProvider.notifier);

    if (!_hydrated && !state.isLoading) {
      _hydrated = true;
      _controllers.hydrate(state);
    }

    final stepIndex = state.step.clamp(0, 3);
    return PopScope(
      canPop: stepIndex == 0 && !state.isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && stepIndex > 0 && !state.isSaving) {
          notifier.goToStep(stepIndex - 1);
        }
      },
      child: THScaffold(
        appBar: THAppBar(
          title: 'Set up your profile',
          subtitle: trOnboardingStepSubtitles[stepIndex],
          leading: stepIndex > 0 && !state.isSaving
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => notifier.goToStep(stepIndex - 1),
                )
              : null,
        ),
        stickyBar: state.isLoading
            ? null
            : THStickyBar(
                children: [
                  if (stepIndex > 0)
                    THButton(
                      label: 'Back',
                      kind: THButtonKind.secondary,
                      onPressed: state.isSaving
                          ? null
                          : () => notifier.goToStep(stepIndex - 1),
                    ),
                  Expanded(
                    child: THButton(
                      label: trOnboardingCtaLabel(
                        stepIndex,
                        isSaving: state.isSaving,
                      ),
                      kind: THButtonKind.accent,
                      onPressed: state.isSaving
                          ? null
                          : () => _onContinue(state, notifier),
                    ),
                  ),
                ],
              ),
        scrollable: true,
        body: state.isLoading
            ? ThStateView.loading()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: Space.s3,
                children: [
                  THProgress(steps: 4, done: stepIndex, current: true),
                  if (state.error != null)
                    THCard(
                      padding: Space.s3,
                      children: [
                        THText(
                          state.error!,
                          style: THTextStyle.meta,
                          tone: THTone.danger,
                        ),
                      ],
                    ),
                  _stepBody(stepIndex, state, notifier),
                ],
              ),
      ),
    );
  }

  Widget _stepBody(
    int stepIndex,
    TradieOnboardingState state,
    TradieOnboardingNotifier notifier,
  ) {
    switch (stepIndex) {
      case 0:
        return TrOnboardingStep0Work(
          state: state,
          notifier: notifier,
          controllers: _controllers,
        );
      case 1:
        return TrOnboardingStep1Trades(
          state: state,
          notifier: notifier,
          controllers: _controllers,
        );
      case 2:
        return TrOnboardingStep2Verification(
          state: state,
          onUploadTap: () => _onUploadDocument(notifier),
        );
      default:
        return TrOnboardingStep3Payout(
          state: state,
          notifier: notifier,
          controllers: _controllers,
        );
    }
  }
}
