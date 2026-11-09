import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/tradie_onboarding.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/locale_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/tradie_onboarding_viewmodel.dart';
import '../widgets/sticky_action_bar.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../../widgets/fixo_states.dart';
import '../widgets/fixo_feedback.dart';


/// Four-section tradie onboarding wizard (P1-09, D7).
///
/// Where you work (profile + weekly availability) → Trades (primary trade +
/// services & rates) → Verification → Payout. Each section validates and
/// saves through [TradieOnboardingNotifier] before the wizard advances, so
/// a partially completed setup is never lost.
class TradieOnboardingWizard extends ConsumerStatefulWidget {
  const TradieOnboardingWizard({super.key});

  @override
  ConsumerState<TradieOnboardingWizard> createState() =>
      _TradieOnboardingWizardState();
}

/// Text controllers for the wizard's inputs, owned by the wizard state and
/// handed to the step widgets so none of them reach up the tree.
class _WizardControllers {
  final PageController page = PageController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  final radius = TextEditingController();

  // P10-17: Bank fields
  final bankAccountName = TextEditingController();
  final bankAccountNumber = TextEditingController();

  final rates = <int, TextEditingController>{};

  TextEditingController rate(TradieOnboardingState state, int serviceId) =>
      rates.putIfAbsent(
        serviceId,
        () => TextEditingController(text: state.rateInputs[serviceId] ?? ''),
      );

  void dispose() {
    page.dispose();
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    address.dispose();
    latitude.dispose();
    longitude.dispose();
    radius.dispose();
    bankAccountName.dispose();
    bankAccountNumber.dispose();
    for (final controller in rates.values) {
      controller.dispose();
    }
  }
}

class _TradieOnboardingWizardState
    extends ConsumerState<TradieOnboardingWizard> {
  final _c = _WizardControllers();
  bool _hydrated = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Seeds the inputs from the loaded state exactly once, so re-entering the
  /// wizard doesn't stomp on whatever the tradie is currently typing.
  void _hydrate(TradieOnboardingState state) {
    if (_hydrated) return;
    _hydrated = true;
    _c.firstName.text = state.firstName;
    _c.lastName.text = state.lastName;
    _c.phone.text = state.phone;
    _c.address.text = state.address;
    _c.latitude.text = state.latitude;
    _c.longitude.text = state.longitude;
    _c.radius.text = state.serviceRadiusKm.toStringAsFixed(0);
    _c.bankAccountName.text = state.bankAccountName;
    _c.bankAccountNumber.text = state.bankAccountNumber;
  }

  Future<void> _next() async {
    final advanced = await ref
        .read(tradieOnboardingProvider.notifier)
        .saveStepAndAdvance();
    if (!advanced || !mounted) return;
    final step = ref.read(tradieOnboardingProvider).step;
    await _c.page.animateToPage(
      step,
      duration: FixoDurations.onboardingSlide,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() async {
    ref.read(tradieOnboardingProvider.notifier).goBack();
    if (!mounted) return;
    await _c.page.previousPage(
      duration: FixoDurations.pageTransition,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final saved = await ref
        .read(tradieOnboardingProvider.notifier)
        .finishSetup();
    if (!saved || !mounted) return;
    // The tradie profile changed on the server, so the shared profile state
    // must be re-read before the dashboard renders.
    ref.invalidate(profileViewModelProvider);
    context.go('/tradie');
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select a credential',
      type: FileType.custom,
      allowedExtensions: kCredentialExtensions,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final path = picked.path;
    if (path == null) {
      _snack('That file could not be read on this device.');
      return;
    }
    if (picked.size > kMaxCredentialBytes) {
      _snack('Credentials must be 10 MB or smaller.');
      return;
    }

    final kind = await _askCredentialKind(picked.name);
    if (kind == null || !mounted) return;

    final ok = await ref
        .read(tradieOnboardingProvider.notifier)
        .uploadCredential(filePath: path, fileName: picked.name, kind: kind);
    if (!ok && mounted) {
      final message = ref.read(tradieOnboardingProvider).step3Error;
      if (message != null) _snack(message);
    }
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<CredentialKind?> _askCredentialKind(String fileName) {
    return showModalBottomSheet<CredentialKind>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.space6,
                DesignTokens.space6,
                DesignTokens.space6,
                DesignTokens.space1,
              ),
              child: Text(
                'What is this document?',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FW.bold,
                  fontFamily: DesignTokens.fontDisplay,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.space6,
              ),
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: DesignTokens.fontMono,
                  fontSize: DesignTokens.fontSizeMono,
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.space3),
            for (final kind in CredentialKind.values)
              ListTile(
                leading: Icon(credentialKindIcon(kind)),
                title: Text(kind.label),
                onTap: () => Navigator.of(sheetContext).pop(kind),
              ),
            const SizedBox(height: DesignTokens.space4),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tradieOnboardingProvider);
    final notifier = ref.read(tradieOnboardingProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_hydrated && !state.isLoading) _hydrate(state);

    final body = state.isLoading
        ? const FixoLoading(label: 'Loading your setup…')
        : state.error != null && state.catalog.isEmpty
        ? FixoErrorState(message: state.error!, onRetry: notifier.load)
        : Column(
            children: [
              _WizardProgress(step: state.step),
              Expanded(
                child: PageView(
                  controller: _c.page,
                  onPageChanged: (page) {
                    if (state.step != page) {
                      notifier.goToStep(page);
                    }
                  },
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _WorkStep(
                      state: state,
                      notifier: notifier,
                      controllers: _c,
                    ),
                    _TradesStep(
                      state: state,
                      notifier: notifier,
                      controllers: _c,
                    ),
                    _VerificationStep(state: state, onPick: _pickAndUpload),
                    _PayoutStep(
                      state: state,
                      notifier: notifier,
                      controllers: _c,
                    ),
                  ],
                ),
              ),
              _WizardFooter(
                state: state,
                onBack: _back,
                onNext: _next,
                onFinish: _finish,
              ),
            ],
          );

    return PopScope(
      canPop: state.isFirstStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.isFirstStep) _back();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? DesignTokens.paperDark : DesignTokens.paperLight,
        appBar: FixoGradientAppBar(
          title: 'Tradie setup',
          subtitle:
              'Step ${state.step + 1} of '
              '${TradieOnboardingState.stepCount} — '
              '${_stepTitles[state.step]}',
          showBack: !state.isFirstStep,
          leading: state.isFirstStep ? const _CloseWizardButton() : null,
        ),
        body: body,
      ),
    );
  }
}

IconData credentialKindIcon(CredentialKind kind) => switch (kind) {
  CredentialKind.license => Icons.badge_outlined,
  CredentialKind.insurance => Icons.shield_outlined,
  CredentialKind.certification => Icons.workspace_premium_outlined,
  CredentialKind.other => Icons.description_outlined,
};

class _CloseWizardButton extends StatelessWidget {
  const _CloseWizardButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Close',
      onPressed: () => context.go('/tradie'),
      icon: Icon(Icons.close_rounded, size: 20, color: DesignTokens.brand900),
    );
  }
}

/// Section titles shown in the step header and app bar.
const _stepTitles = ['Where you work', 'Your trades', 'Verification', 'Payout'];

/// Short progress-rail labels — kept terse so all four fit at comfortable
/// widths. At narrow or large-text sizes only the current one is shown.
const _stepLabels = ['Work', 'Trades', 'Verify', 'Payout'];

/// Four-dot progress indicator with a section label beneath each step.
class _WizardProgress extends StatelessWidget {
  final int step;

  const _WizardProgress({required this.step});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = isDark
        ? DesignTokens.paperLineDark
        : DesignTokens.paperLineLight;
    final muted = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Effective logical width at the current text scale — decides
        // whether all four labels fit or only the current one is shown.
        final effectiveWidth =
            constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1);
        final showAllLabels = effectiveWidth >= 300;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            DesignTokens.space6,
            DesignTokens.space5,
            DesignTokens.space6,
            DesignTokens.space2,
          ),
          child: Semantics(
            label:
                'Step ${step + 1} of ${TradieOnboardingState.stepCount}: '
                '${_stepTitles[step]}',
            child: Column(
              children: [
                Row(
                  children: [
                    for (
                      var i = 0;
                      i < TradieOnboardingState.stepCount;
                      i++
                    ) ...[
                      if (i > 0)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i <= step ? DesignTokens.amber : track,
                          ),
                        ),
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= step
                              ? DesignTokens.amber
                              : (DesignTokens.surfaceCard(isDark)),
                          border: Border.all(
                            color: i <= step ? DesignTokens.amber : track,
                            width: DesignTokens.borderWidthFor(isDark),
                          ),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontFamily: DesignTokens.fontMono,
                            fontSize: DesignTokens.fontSizeCaption,
                            fontWeight: FW.semibold,
                            color: i <= step ? DesignTokens.onAmber : muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: DesignTokens.space1),
                Row(
                  children: [
                    for (var i = 0; i < TradieOnboardingState.stepCount; i++)
                      Expanded(
                        child: Text(
                          (showAllLabels || i == step) ? _stepLabels[i] : '',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: DesignTokens.fontDisplay,
                            fontSize: DesignTokens.fontSizeCaption,
                            fontWeight: i == step
                                ? FW.semibold
                                : FW.regular,
                            color: i <= step
                                ? (isDark
                                      ? DesignTokens.inkDark
                                      : DesignTokens.inkLight)
                                : muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WizardFooter extends StatelessWidget {
  final TradieOnboardingState state;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const _WizardFooter({
    required this.state,
    required this.onBack,
    required this.onNext,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return StickyActionBar(
      child: Row(
        children: [
          if (!state.isFirstStep) ...[
            Expanded(
              child: FixoGhostButton(
                label: 'Back',
                onPressed: state.isSaving ? null : onBack,
              ),
            ),
            const SizedBox(width: DesignTokens.space3),
          ],
          Expanded(
            flex: 2,
            child: FixoPrimaryButton(
              label: state.isLastStep ? 'Finish setup' : 'Continue',
              isLoading: state.isSaving,
              onPressed: state.isSaving
                  ? null
                  : (state.isLastStep ? onFinish : onNext),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Step 1: where you work ──────────────────────────────────────────────────

class _WorkStep extends StatelessWidget {
  final TradieOnboardingState state;
  final TradieOnboardingNotifier notifier;
  final _WizardControllers controllers;

  const _WorkStep({
    required this.state,
    required this.notifier,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context) {
    final activeDays = state.schedule.length;
    final quickFillLabel = activeDays == 0
        ? 'Weekdays, 8am – 5pm'
        : 'Clear all days';

    return _StepScroll(
      title: 'Where you work',
      subtitle:
          'Homeowners only see tradies near them — your base, radius and '
          'available days decide which local leads you get.',
      error: state.step1Error,
      children: [
        const FixoSectionLabel(label: 'Your details', uppercase: true),
        const SizedBox(height: DesignTokens.space3),
        _Field(
          label: 'First name',
          hint: 'Jamie',
          controller: controllers.firstName,
          error: state.fieldErrors['firstName'],
          onChanged: notifier.setFirstName,
        ),
        const SizedBox(height: DesignTokens.space4),
        _Field(
          label: 'Last name',
          hint: 'Ngata',
          controller: controllers.lastName,
          error: state.fieldErrors['lastName'],
          onChanged: notifier.setLastName,
        ),
        const SizedBox(height: DesignTokens.space4),
        _Field(
          label: 'Phone',
          hint: '+64 21 555 0182',
          helper: 'Used for job notifications. This number is not verified.',
          controller: controllers.phone,
          error: state.fieldErrors['phone'],
          keyboardType: TextInputType.phone,
          formatter: _phoneFormatter,
          onChanged: notifier.setPhone,
        ),
        const SizedBox(height: DesignTokens.space6),
        const FixoSectionLabel(label: 'Service area', helper: 'Jobs outside your patch are never sent to you.', uppercase: true),
        const SizedBox(height: DesignTokens.space3),
        _Field(
          label: 'Base address',
          hint: '12 Queen Street, Auckland CBD',
          controller: controllers.address,
          error: state.fieldErrors['address'],
          onChanged: notifier.setAddress,
        ),
        const SizedBox(height: DesignTokens.space4),
        _Field(
          label: 'Service radius',
          hint: '25',
          helper: 'How far you are willing to travel for a job.',
          controller: controllers.radius,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          formatter: _decimalFormatter,
          onChanged: (value) {
            final parsed = parseDecimal(value);
            if (parsed != null) notifier.setServiceRadiusKm(parsed);
          },
          suffix: const Text('km', style: _monoStyle),
        ),
        const SizedBox(height: DesignTokens.space4),
        _CoordinatesCard(
          latitudeController: controllers.latitude,
          longitudeController: controllers.longitude,
          latitudeError: state.fieldErrors['latitude'],
          longitudeError: state.fieldErrors['longitude'],
          onLatitudeChanged: notifier.setLatitude,
          onLongitudeChanged: notifier.setLongitude,
        ),
        const SizedBox(height: DesignTokens.space6),
        FixoSectionLabel(
          label: 'Weekly availability',
          helper: activeDays == 0
              ? 'No days selected yet — homeowners can\'t book you.'
              : 'Available $activeDays ${activeDays == 1 ? "day" : "days"} '
                    'a week.',
          uppercase: true,
        ),
        const SizedBox(height: DesignTokens.space3),
        FixoCard(
          child: Column(
            children: [
              for (final weekday in kWeekdayOrder) ...[
                _DayRow(
                  weekday: weekday,
                  slot: state.schedule[weekday],
                  error: state.fieldErrors['day:$weekday'],
                  onToggle: (enabled) =>
                      notifier.setDayEnabled(weekday, enabled),
                  onStart: (time) => notifier.setDayTimes(weekday, start: time),
                  onEnd: (time) => notifier.setDayTimes(weekday, end: time),
                ),
                if (weekday != kWeekdayOrder.last) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space4),
        FixoGhostButton(
          label: quickFillLabel,
          onPressed: () {
            // Sunday is 0 and Saturday is 6 in .NET's DayOfWeek.
            final fill = activeDays == 0;
            for (final weekday in kWeekdayOrder) {
              notifier.setDayEnabled(
                weekday,
                fill && weekday != 0 && weekday != 6,
              );
            }
          },
        ),
      ],
    );
  }
}

/// Full-width tappable selector for the primary trade — clearer than an
/// icon-only menu and tall enough to hit comfortably.
class _TradeSelector extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final String? error;
  final ValueChanged<String> onSelected;

  const _TradeSelector({
    required this.categories,
    required this.selected,
    this.error,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;
    final line = isDark
        ? DesignTokens.paperLineDark
        : DesignTokens.paperLineLight;
    final hasSelection = selected.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRIMARY TRADE',
          style: TextStyle(
            fontFamily: DesignTokens.fontBody,
            fontSize: DesignTokens.fontSizeCaption,
            fontWeight: FW.semibold,
            letterSpacing: Tracking.widest,
            color: muted,
          ),
        ),
        const SizedBox(height: DesignTokens.space2),
        Semantics(
          button: true,
          label: hasSelection
              ? 'Primary trade: $selected. Tap to change.'
              : 'Choose your primary trade',
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.space3,
                vertical: DesignTokens.space3,
              ),
              decoration: BoxDecoration(
                color: DesignTokens.surfaceCard(isDark),
                borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                border: Border.all(
                  color: error != null ? DesignTokens.inkDanger(isDark) : line,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.construction_rounded,
                    size: 20,
                    color: hasSelection ? DesignTokens.brand500 : muted,
                  ),
                  const SizedBox(width: DesignTokens.space3),
                  Expanded(
                    child: Text(
                      hasSelection ? selected : 'Choose your primary trade',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: hasSelection ? null : muted,
                      ),
                    ),
                  ),
                  Icon(Icons.unfold_more_rounded, size: 20, color: muted),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: DesignTokens.space1),
          Text(
            error!,
            style: TextStyle(
              color: DesignTokens.inkDanger(isDark),
              fontSize: DesignTokens.fontSizeBody - 2,
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.space1),
            child: Text(
              'The trade your jobs are matched against.',
              style: TextStyle(fontSize: DesignTokens.fontSizeCaption, color: muted),
            ),
          ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.space6,
                DesignTokens.space6,
                DesignTokens.space6,
                DesignTokens.space3,
              ),
              child: Text(
                'Primary trade',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FW.bold,
                  fontFamily: DesignTokens.fontDisplay,
                ),
              ),
            ),
            Flexible(
              child: RadioGroup<String>(
                groupValue: selected.isEmpty ? null : selected,
                onChanged: (value) => Navigator.of(sheetContext).pop(value),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final category in categories)
                      RadioListTile<String>(
                        value: category,
                        title: Text(category),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.space6,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.space4),
          ],
        ),
      ),
    );
    if (picked != null) onSelected(picked);
  }
}

/// The backend has no geocoding endpoint yet, so the geo point is entered
/// directly. Both coordinates must be present or both blank — the API
/// validator rejects one without the other, and matching skips tradies with
/// no location at all.
class _CoordinatesCard extends StatefulWidget {
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final String? latitudeError;
  final String? longitudeError;
  final ValueChanged<String> onLatitudeChanged;
  final ValueChanged<String> onLongitudeChanged;

  const _CoordinatesCard({
    required this.latitudeController,
    required this.longitudeController,
    this.latitudeError,
    this.longitudeError,
    required this.onLatitudeChanged,
    required this.onLongitudeChanged,
  });

  @override
  State<_CoordinatesCard> createState() => _CoordinatesCardState();
}

class _CoordinatesCardState extends State<_CoordinatesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasValues =
        widget.latitudeController.text.isNotEmpty ||
        widget.longitudeController.text.isNotEmpty;

    return FixoCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(
              Icons.my_location_rounded,
              color: hasValues ? DesignTokens.inkSuccess(isDark) : null,
            ),
            title: const Text('Precise coordinates'),
            subtitle: Text(
              hasValues
                  ? 'Matching will use this point'
                  : 'Optional, but without it you won\'t be matched',
              style: TextStyle(
                color: isDark
                    ? DesignTokens.inkSoftDark
                    : DesignTokens.inkSoftLight,
              ),
            ),
            trailing: Icon(
              _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space4),
              child: Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Latitude',
                      hint: '-36.8485',
                      controller: widget.latitudeController,
                      error: widget.latitudeError,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      formatter: _signedDecimalFormatter,
                      onChanged: (v) {
                        widget.onLatitudeChanged(v);
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space3),
                  Expanded(
                    child: _Field(
                      label: 'Longitude',
                      hint: '174.7633',
                      controller: widget.longitudeController,
                      error: widget.longitudeError,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      formatter: _signedDecimalFormatter,
                      onChanged: (v) {
                        widget.onLongitudeChanged(v);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Step 2: trades ──────────────────────────────────────────────────────────

class _TradesStep extends ConsumerWidget {
  final TradieOnboardingState state;
  final TradieOnboardingNotifier notifier;
  final _WizardControllers controllers;

  const _TradesStep({
    required this.state,
    required this.notifier,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencySymbol = currencySymbolOf(
      ref.watch(localeConfigProvider).value,
    );
    final servicesError = state.fieldErrors['services'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.catalog.isEmpty) {
      return const FixoEmptyState(
        icon: Icons.handyman_outlined,
        title: 'No services available',
        subtitle: 'The trade catalog is empty. Try again in a moment.',
      );
    }

    return _StepScroll(
      title: 'Your trades',
      subtitle:
          'Your primary trade and the services you take on decide which '
          'jobs reach you — pick what you do and set your hourly rate.',
      error: state.step2Error,
      children: [
        _TradeSelector(
          categories: state.tradeCategories,
          selected: state.tradeType,
          error: state.fieldErrors['tradeType'],
          onSelected: notifier.setTradeType,
        ),
        const SizedBox(height: DesignTokens.space6),
        FixoSectionLabel(label: 'Services & rates', helper: 'Tick every service you take on and set its hourly rate.', uppercase: true),
        if (servicesError != null) ...[
          const SizedBox(height: DesignTokens.space2),
          Text(
            servicesError,
            style: TextStyle(
              color: DesignTokens.inkDanger(isDark),
              fontSize: DesignTokens.fontSizeBody - 2,
            ),
          ),
        ],
        const SizedBox(height: DesignTokens.space3),
        // Show only services that belong to the selected trade (V16-16).
        // If no trade is selected yet, show a prompt to choose one first.
        if (state.tradeType.isEmpty)
          FixoCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DesignTokens.space4),
              child: Text(
                'Choose your primary trade above to see its services.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? DesignTokens.inkSoftDark
                      : DesignTokens.inkSoftLight,
                ),
              ),
            ),
          )
        else
          for (final entry in state.catalogByCategory.entries)
            if (entry.key == state.tradeType) ...[
              FixoCard(
                child: Column(
                  children: [
                    for (final service in entry.value)
                      _ServiceRow(
                        service: service,
                        selected: state.rates.containsKey(service.id),
                        rateController: controllers.rate(state, service.id),
                        rateError: state.fieldErrors['rate:${service.id}'],
                        currencySymbol: currencySymbol,
                        onToggle: () => notifier.toggleService(service),
                        onRateChanged: (value) =>
                            notifier.setRateInput(service, value),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.space4),
            ],
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final TradieService service;
  final bool selected;
  final TextEditingController rateController;
  final String? rateError;
  final String currencySymbol;
  final VoidCallback onToggle;
  final ValueChanged<String> onRateChanged;

  const _ServiceRow({
    required this.service,
    required this.selected,
    required this.rateController,
    this.rateError,
    required this.currencySymbol,
    required this.onToggle,
    required this.onRateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            value: selected,
            onChanged: (_) => onToggle(),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              service.name,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: selected ? FW.semibold : FW.regular,
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(height: DesignTokens.space2),
            _Field(
              label: 'Hourly rate',
              hint: '85.00',
              controller: rateController,
              error: rateError,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              formatter: _decimalFormatter,
              onChanged: onRateChanged,
              prefix: Text(
                currencySymbol,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.space2),
          ],
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final int weekday;
  final TradieScheduleSlot? slot;
  final String? error;
  final ValueChanged<bool> onToggle;
  final ValueChanged<TimeOfDay> onStart;
  final ValueChanged<TimeOfDay> onEnd;

  const _DayRow({
    required this.weekday,
    required this.slot,
    this.error,
    required this.onToggle,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Single-row layout only when the switch, label and both time
          // buttons genuinely fit — otherwise the times move to their own
          // line. Effective width discounts the text scale.
          final effectiveWidth =
              constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1);
          final singleRow = effectiveWidth >= 360;
          final times = _Times(
            slot: slot,
            muted: muted,
            onStart: onStart,
            onEnd: onEnd,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Switch(value: slot != null, onChanged: onToggle),
                  ),
                  Expanded(
                    child: Text(
                      weekdayShortLabel(weekday),
                      style: TextStyle(
                        fontFamily: DesignTokens.fontDisplay,
                        fontWeight: FW.semibold,
                        fontSize: DesignTokens.fontSizeBody,
                        color: error != null
                            ? DesignTokens.inkDanger(isDark)
                            : (isDark
                                  ? DesignTokens.inkDark
                                  : DesignTokens.inkLight),
                      ),
                    ),
                  ),
                  if (slot == null)
                    Text(
                      'Unavailable',
                      style: _monoStyle.copyWith(color: muted),
                    )
                  else if (singleRow)
                    times,
                ],
              ),
              if (slot != null && !singleRow)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 56,
                    top: DesignTokens.space1,
                  ),
                  child: Align(alignment: Alignment.centerRight, child: times),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 56,
                    top: DesignTokens.space1,
                  ),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: DesignTokens.inkDanger(isDark),
                      fontSize: DesignTokens.fontSizeBody - 2,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The `start – end` time pair for an enabled day. Rendered as a [Wrap] so
/// the buttons can stack rather than overflow at large text sizes.
class _Times extends StatelessWidget {
  final TradieScheduleSlot? slot;
  final Color muted;
  final ValueChanged<TimeOfDay> onStart;
  final ValueChanged<TimeOfDay> onEnd;

  const _Times({
    required this.slot,
    required this.muted,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final slot = this.slot;
    if (slot == null) return const SizedBox.shrink();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: DesignTokens.space2,
      runSpacing: DesignTokens.space1,
      children: [
        _TimeButton(
          label: slot.start.format(context),
          onPressed: () => _pick(context, slot.start, onStart),
        ),
        Text('–', style: TextStyle(color: muted)),
        _TimeButton(
          label: slot.end.format(context),
          onPressed: () => _pick(context, slot.end, onEnd),
        ),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) onPicked(picked);
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _TimeButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space3,
          vertical: DesignTokens.space2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
          border: Border.all(
            color: isDark
                ? DesignTokens.paperLineDark
                : DesignTokens.paperLineLight,
          ),
        ),
        child: Text(
          label,
          style: _monoStyle.copyWith(
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
      ),
    );
  }
}

// ── Step 3: verification ────────────────────────────────────────────────────

class _VerificationStep extends StatelessWidget {
  final TradieOnboardingState state;
  final VoidCallback onPick;

  const _VerificationStep({required this.state, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pending = state.credentials.where((c) => c.isPending).length;
    final approved = state.credentials.where((c) => c.isApproved).length;

    return _StepScroll(
      title: 'Verification',
      subtitle:
          'Upload a licence, insurance or certification. An admin reviews '
          'it, and a verified badge shows on your profile once one is '
          'approved.',
      error: state.step3Error,
      children: [
        if (state.credentials.isNotEmpty) ...[
          Row(
            children: [
              StatusBadge(label: '$pending pending', kind: FixoBadgeKind.waiting),
              const SizedBox(width: DesignTokens.space2),
              StatusBadge(
                label: '$approved approved',
                kind: FixoBadgeKind.done,
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space4),
          for (final credential in state.credentials) ...[
            _CredentialRow(credential: credential),
            const SizedBox(height: DesignTokens.space2),
          ],
        ] else
          FixoCard(
            child: Column(
              children: [
                Icon(
                  Icons.upload_file_rounded,
                  size: 40,
                  color: isDark
                      ? DesignTokens.inkSoftDark
                      : DesignTokens.inkSoftLight,
                ),
                const SizedBox(height: DesignTokens.space3),
                const Text(
                  'No documents uploaded yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: DesignTokens.fontDisplay,
                    fontWeight: FW.semibold,
                  ),
                ),
                const SizedBox(height: DesignTokens.space2),
                Text(
                  'JPEG, PNG or PDF, up to 10 MB each.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? DesignTokens.inkSoftDark
                        : DesignTokens.inkSoftLight,
                  ),
                ),
              ],
            ),
          ),
        if (state.uploadingFileName != null) ...[
          const SizedBox(height: DesignTokens.space4),
          FixoCard(
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: DesignTokens.space3),
                Expanded(
                  child: Text(
                    'Uploading ${state.uploadingFileName}…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _monoStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Upload document button below the cards (V16-16: 48px secondary button).
        const SizedBox(height: DesignTokens.space4),
        FixoTonalButton(
          key: const Key('upload_document_button'),
          icon: Icons.upload_file_rounded,
          label: 'Upload document',
          onPressed: state.uploadingFileName == null ? onPick : null,
          fullWidth: true,
          height: 48,
        ),
      ],
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final TradieCredential credential;

  const _CredentialRow({required this.credential});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kind = CredentialKind.fromWire(credential.type);

    return FixoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            credentialKindIcon(kind),
            size: 20,
            color: DesignTokens.brand500,
          ),
          const SizedBox(width: DesignTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind.label,
                  style: const TextStyle(fontWeight: FW.semibold),
                ),
                const SizedBox(height: Space.s0_5),
                Text(
                  credential.originalFileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _monoStyle.copyWith(
                    color: isDark
                        ? DesignTokens.inkSoftDark
                        : DesignTokens.inkSoftLight,
                  ),
                ),
                if (credential.isRejected &&
                    credential.rejectReason != null) ...[
                  const SizedBox(height: DesignTokens.space2),
                  Text(
                    credential.rejectReason!,
                    style: TextStyle(
                      color: DesignTokens.inkDanger(isDark),
                      fontSize: DesignTokens.fontSizeBody - 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: DesignTokens.space3),
          StatusBadge(
            label: credential.status,
            kind: switch (credential.status.toLowerCase()) {
              'approved' => FixoBadgeKind.done,
              'rejected' => FixoBadgeKind.problem,
              _ => FixoBadgeKind.waiting,
            },
          ),
        ],
      ),
    );
  }
}

// ── Step 4: payout ──────────────────────────────────────────────────────────

class _PayoutStep extends StatelessWidget {
  final TradieOnboardingState state;
  final TradieOnboardingNotifier notifier;
  final _WizardControllers controllers;

  const _PayoutStep({
    required this.state,
    required this.notifier,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;

    return _StepScroll(
      title: 'Payout',
      subtitle:
          'Where we send payouts for your completed jobs — a bank account '
          'in your name.',
      error: state.step4Error,
      children: [
        _Field(
          label: 'Account name',
          hint: 'Jamie Ngata',
          controller: controllers.bankAccountName,
          onChanged: notifier.setBankAccountName,
        ),
        const SizedBox(height: DesignTokens.space4),
        _Field(
          label: 'Account number',
          hint: '12-3456-7890123-45',
          helper: 'Optional now, but required before your first payout.',
          controller: controllers.bankAccountNumber,
          error: state.fieldErrors['bankAccountNumber'],
          onChanged: notifier.setBankAccountNumber,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: DesignTokens.space6),
        FixoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: muted),
              const SizedBox(width: DesignTokens.space3),
              Expanded(
                child: Text(
                  'Only you can see these details — they are never shown '
                  'on your public profile.',
                  style: TextStyle(fontSize: DesignTokens.fontSizeSecondary, color: muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared step scaffolding ─────────────────────────────────────────────────

class _StepScroll extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? error;
  final List<Widget> children;

  const _StepScroll({
    required this.title,
    required this.subtitle,
    this.error,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FixoResponsive(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          DesignTokens.space6,
          DesignTokens.space2,
          DesignTokens.space6,
          // Bottom padding must clear the sticky CTA (56px primary button +
          // 12px top + 16px bottom safe inset + 20px margin) — use 104px to
          // ensure content is reachable at all text scales.
          104,
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: DesignTokens.fontDisplay,
                  fontWeight: FW.bold,
                ),
              ),
              const SizedBox(height: DesignTokens.space2),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: DesignTokens.space4),
            FixoInfoBanner.error(message: error!),
          ],
          const SizedBox(height: DesignTokens.space6),
          ...children,
        ],
      ),
    );
  }
}


const _monoStyle = TextStyle(
  fontFamily: DesignTokens.fontMono,
  fontSize: DesignTokens.fontSizeMono,
);

final _decimalFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));
final _signedDecimalFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9.\-+]'),
);
final _phoneFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9+()\-\s]'),
);

class _Field extends StatelessWidget {
  final String label;
  final String? helper;
  final String? hint;
  final TextEditingController? controller;
  final String? error;
  final TextInputType? keyboardType;
  final TextInputFormatter? formatter;
  final ValueChanged<String>? onChanged;
  final Widget? prefix;
  final Widget? suffix;

  const _Field({
    required this.label,
    this.helper,
    this.hint,
    this.controller,
    this.error,
    this.keyboardType,
    this.formatter,
    this.onChanged,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight;
    // Bound to a local so the null check promotes it — a public final field
    // on a widget isn't promotable.
    final TextInputFormatter? inputFormatter = formatter;

    InputDecoration decoration() => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: muted),
      errorText: error,
      prefixIcon: prefix == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(
                left: DesignTokens.space3,
                right: DesignTokens.space2,
              ),
              child: prefix,
            ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0),
      suffixIcon: suffix,
      filled: true,
      fillColor: DesignTokens.surfaceCard(isDark),
      isDense: true,
      // Keeps the field at least 56 px tall even with density adjustments.
      constraints: const BoxConstraints(minHeight: 56),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space3,
        vertical: DesignTokens.space4,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        borderSide: BorderSide(color: _lineColor(isDark)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        borderSide: BorderSide(color: _lineColor(isDark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        borderSide: BorderSide(color: DesignTokens.brand500, width: 2),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: DesignTokens.fontBody,
            fontSize: DesignTokens.fontSizeCaption,
            fontWeight: FW.semibold,
            letterSpacing: Tracking.widest,
            color: muted,
          ),
        ),
        const SizedBox(height: DesignTokens.space2),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatter == null
              ? null
              : <TextInputFormatter>[inputFormatter],
          onChanged: onChanged,
          style: theme.textTheme.bodyLarge,
          decoration: decoration(),
        ),
        if (helper != null) ...[
          const SizedBox(height: DesignTokens.space1),
          Text(helper!, style: TextStyle(fontSize: DesignTokens.fontSizeCaption, color: muted)),
        ],
      ],
    );
  }

  static Color _lineColor(bool isDark) =>
      isDark ? DesignTokens.paperLineDark : DesignTokens.paperLineLight;
}
