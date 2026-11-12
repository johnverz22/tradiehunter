import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/address_viewmodel.dart';
import '../widgets/sticky_action_bar.dart';
import '../widgets/fixo_filter_pill.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../../widgets/fixo_states.dart';
import '../../feedback/fixo_notice.dart';

/// Post a job screen: category/service picker, address resolution,
/// description, photo upload, date picker, urgency segmented control,
/// hourly rate selection, live estimate card, and sticky Post Job action.
/// Wired to [PostJobNotifier] (M2-07). Photos are uploaded to
/// POST /api/jobs/:id/photos after job creation.
///
/// Role-guarded: tradies are redirected to /tradie — only homeowners
/// can post jobs.
class PostJobScreen extends ConsumerWidget {
  const PostJobScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tradies cannot post jobs — redirect them to their dashboard.
    // Backend UserRole: Homeowner=0, Tradie=1, Staff=2, Superadmin=3 (serialized as int).
    final role = ref.read(profileViewModelProvider).profile?['role'];
    final isTradie = role == 1 || role == 'Tradie';
    if (isTradie) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/tradie');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final vm = ref.watch(postJobProvider);
    final notifier = ref.read(postJobProvider.notifier);
    final theme = Theme.of(context);

    final missingHelper = _getMissingFieldHelper(vm);
    final canSubmit = !vm.isSubmitting && (vm.submittedJobId != null || vm.isValid);

    return Scaffold(
      key: const Key('post_job_screen'),
      appBar: const FixoGradientAppBar(title: 'Post a Job'),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
            padding: FixoPadding.page,
            child: AbsorbPointer(
              absorbing: vm.isSubmitting || vm.submittedJobId != null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Service ────────────────────────────────────────────────────
                  const _Section(title: 'What do you need?'),
                  DropdownButtonFormField<int>(
                    key: const Key('service_dropdown'),
                    initialValue: vm.selectedService?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Service',
                      hintText: 'Choose a service',
                    ),
                    items: vm.services
                        .map(
                          (service) => DropdownMenuItem(
                            value: service.id,
                            child: Text(
                              service.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      notifier.selectService(
                        vm.services.firstWhere((s) => s.id == id),
                      );
                    },
                  ),
                  if (vm.isLoadingServices)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Loading services',
                    ),
                  if (!vm.isLoadingServices && vm.services.isEmpty)
                    TextButton(
                      onPressed: notifier.loadServices,
                      child: const Text('Retry loading services'),
                    ),
                  const SizedBox(height: Space.s6),

                  // ── Where is the job? ──────────────────────────────────────────
                  const _Section(title: 'Where is the job?'),
                  const _AddressField(),
                  const SizedBox(height: Space.s6),

                  // ── Description ────────────────────────────────────────────────
                  const _Section(title: 'Describe the job'),
                  TextField(
                    key: const Key('title_field'),
                    maxLength: 200,
                    buildCounter: _hideCounterUntilThreshold(threshold: 0.8),
                    decoration: const InputDecoration(
                      labelText: 'Job title',
                      hintText: 'e.g. Fix a leaking kitchen tap',
                    ),
                    onChanged: notifier.setTitle,
                  ),
                  const SizedBox(height: Space.s3),
                  TextField(
                    key: const Key('description_field'),
                    maxLines: 5,
                    maxLength: 2000,
                    buildCounter: _hideCounterUntilThreshold(threshold: 0.8),
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'e.g. Leaking kitchen tap, drips constantly…',
                    ),
                    onChanged: notifier.setDescription,
                  ),
                  if (vm.error != null && vm.error!.contains('description'))
                    Padding(
                      padding: const EdgeInsets.only(top: Space.s1),
                      child: Text(
                        vm.error!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: DesignTokens.fontSizeCaption,
                        ),
                      ),
                    ),
                  const SizedBox(height: Space.s6),

                  // ── Photos (moved up right after Description) ─────────────────
                  const _Section(title: 'Photos (up to 5)'),
                  Text(
                    '${vm.photoPaths.length}/5 photos added',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: vm.photoPaths.length >= 5
                          ? DesignTokens.amber
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FW.medium,
                    ),
                  ),
                  const SizedBox(height: Space.s2),
                  _PhotoGrid(
                    paths: vm.photoPaths,
                    onAdd: () => _pickPhoto(context, ref),
                    onRemove: (path) => notifier.removePhoto(path),
                  ),
                  const SizedBox(height: Space.s6),

                  // ── When & Urgency ─────────────────────────────────────────────
                  const _Section(title: 'When do you need help?'),
                  InkWell(
                    key: const Key('scheduled_start_field'),
                    onTap: () => _pickScheduledStart(context, ref),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: DesignTokens.heightInput,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusInput,
                        ),
                        border: Border.all(
                          color: DesignTokens.borderControl(
                            theme.brightness == Brightness.dark,
                          ),
                          width: DesignTokens.borderWidthFor(
                            theme.brightness == Brightness.dark,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: Space.s3),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scheduled start',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: DesignTokens.fontSizeCaption,
                                  ),
                                ),
                                const SizedBox(height: Space.s0_5),
                                Text(
                                  vm.scheduledStartLocal == null
                                      ? 'Choose a start date and time'
                                      : '${MaterialLocalizations.of(context).formatFullDate(vm.scheduledStartLocal!)} · '
                                          '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(vm.scheduledStartLocal!))}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: vm.scheduledStartLocal == null
                                      ? theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.hintColor,
                                        )
                                      : theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s4),
                  const _Section(title: 'Urgency'),
                  _UrgencySegmentedControl(
                    selected: vm.urgency,
                    onSelected: notifier.setUrgency,
                  ),
                  const SizedBox(height: Space.s6),

                  // ── Hours and hourly rate ──────────────────────────────────────
                  const _Section(title: 'Hours and hourly rate'),
                  TextFormField(
                    key: const Key('hours_field'),
                    initialValue: vm.hours.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Estimated hours',
                    ),
                    onChanged: notifier.setHours,
                  ),
                  const SizedBox(height: Space.s3),
                  if (vm.isLoadingRates)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Finding nearby rates',
                    )
                  else if (vm.rateOptions.isEmpty) ...[
                    Text(
                      vm.resolvedAddress == null
                          ? 'Select an address to see nearby rates.'
                          : 'No available rates loaded for this service and location.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (vm.resolvedAddress != null && vm.selectedService != null) ...[
                      const SizedBox(height: Space.s2_5),
                      FixoTonalButton(
                        label: 'Search nearby rates',
                        icon: Icons.search,
                        onPressed: notifier.searchRates,
                      ),
                    ],
                  ] else ...[
                    ...vm.rateOptions.map(
                      (rate) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          '\$${rate.hourlyRate.toStringAsFixed(2)} / hour',
                        ),
                        subtitle: Text(
                          '${rate.businessName ?? rate.name} · ${rate.distanceKm.toStringAsFixed(1)} km away',
                        ),
                        value: vm.selectedRate?.tradieId == rate.tradieId,
                        onChanged: (_) => notifier.selectRate(rate),
                      ),
                    ),
                    const SizedBox(height: Space.s2),
                    FixoTonalButton(
                      label: 'Search nearby rates',
                      icon: Icons.refresh,
                      onPressed: notifier.searchRates,
                    ),
                  ],
                  const SizedBox(height: Space.s6),

                  // ── Review your job (Live estimate card) ───────────────────────
                  const _Section(title: 'Review your job'),
                  _LiveEstimateCard(vm: vm),

                  // ── Error banner ────────────────────────────────────────────────
                  if (vm.error != null && !vm.error!.contains('description'))
                    Padding(
                      padding: const EdgeInsets.only(top: Space.s4),
                      child: Text(
                        vm.error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      bottomNavigationBar: StickyActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FixoPrimaryButton(
              key: const Key('post_job_button'),
              label: vm.submittedJobId == null ? 'Post Job' : 'Retry photo upload',
              isLoading: vm.isSubmitting,
              onPressed: canSubmit ? () => _submit(context, ref) : null,
            ),
            if (missingHelper != null) ...[
              const SizedBox(height: Space.s2),
              Text(
                missingHelper,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FW.medium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _getMissingFieldHelper(PostJobState vm) {
    if (vm.submittedJobId != null) return null;
    if (vm.selectedService == null) {
      return 'Select a service to post your job';
    }
    if (vm.resolvedAddress == null) {
      return 'Select a job address to post your job';
    }
    if (vm.title.trim().isEmpty) {
      return 'Add a title to post your job';
    }
    if (vm.description.trim().isEmpty) {
      return 'Add a description to post your job';
    }
    if (vm.scheduledStartLocal == null) {
      return 'Choose a start date and time to post your job';
    }
    if (vm.hours <= 0) {
      return 'Enter estimated hours to post your job';
    }
    if (vm.selectedRate == null) {
      return 'Choose an hourly rate to post your job';
    }
    return null;
  }

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(postJobProvider.notifier);
    final state = ref.read(postJobProvider);
    if (state.photoPaths.length >= 5) return;

    final picker = ImagePicker();
    final source = await _showSourceDialog(context);
    if (source == null) return;

    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;

    // P10-25: enforce 10 MB per-photo limit before adding.
    const maxBytes = 10 * 1024 * 1024; // 10 MB
    final fileSize = await File(file.path).length();
    if (fileSize > maxBytes) {
      if (context.mounted) {
        FixoNotice.warning(context, 'Photo exceeds 10 MB. Please choose a smaller image.');
      }
      return;
    }

    notifier.addPhoto(file.path);
  }

  Future<void> _pickScheduledStart(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: ref.read(postJobProvider).scheduledStartLocal ?? now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    ref
        .read(postJobProvider.notifier)
        .setScheduledStartLocal(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
  }

  Future<ImageSource?> _showSourceDialog(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final jobId = await ref.read(postJobProvider.notifier).submit();
    if (jobId != null && context.mounted) {
      context.push('/jobs/$jobId/matching');
    }
  }
}

/// Helper counter callback that hides the counter until current length is >= 80% of maxLength.
InputCounterWidgetBuilder _hideCounterUntilThreshold({double threshold = 0.8}) {
  return (
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) {
    if (maxLength == null || currentLength < (maxLength * threshold).ceil()) {
      return null;
    }
    return Text(
      '$currentLength / $maxLength',
      style: Theme.of(context).textTheme.bodySmall,
    );
  };
}

// ── Urgency segmented control ────────────────────────────────────────────────

class _UrgencySegmentedControl extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _UrgencySegmentedControl({
    required this.selected,
    required this.onSelected,
  });

  static const _urgencies = ['Low', 'Medium', 'High', 'Emergency'];
  static const _meanings = {
    'Low': 'Flexible timing · needed within the next week or two',
    'Medium': 'Standard priority · needed within the next few days',
    'High': 'High priority · needed within 24–48 hours',
    'Emergency': 'Immediate response · needed today or ASAP',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(13) > 15;
            if (isNarrow) {
              return _buildGrid(context, isDark);
            }
            return _buildBar(context, isDark);
          },
        ),
        const SizedBox(height: Space.s2),
        Text(
          _meanings[selected] ?? '',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildBar(BuildContext context, bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceTonal(isDark),
        borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
        border: Border.all(color: DesignTokens.borderControl(isDark)),
      ),
      child: Row(
        children: _urgencies.map((u) {
          final isSelected = u == selected;
          return Expanded(
            child: InkWell(
              onTap: () => onSelected(u),
              borderRadius: BorderRadius.circular(DesignTokens.radiusControl - 2),
              child: AnimatedContainer(
                duration: FixoDurations.fast,
                alignment: Alignment.center,
                margin: const EdgeInsets.all(Space.s0_5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? DesignTokens.brand700 : DesignTokens.brand900)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusControl - 2),
                ),
                child: Text(
                  u,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSecondary,
                    fontWeight: isSelected ? FW.bold : FW.medium,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? DesignTokens.inkDark : DesignTokens.inkLight),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, bool isDark) {
    return Wrap(
      spacing: Space.s2,
      runSpacing: Space.s2,
      children: _urgencies.map((u) {
        final isSelected = u == selected;
        return FixoFilterPill(
          label: u,
          selected: isSelected,
          onSelected: (_) => onSelected(u),
        );
      }).toList(),
    );
  }
}

// ── Live estimate card ───────────────────────────────────────────────────────

class _LiveEstimateCard extends StatelessWidget {
  final PostJobState vm;

  const _LiveEstimateCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasExactEstimate = vm.selectedRate != null && vm.hours > 0;
    final hasRange = !hasExactEstimate && vm.rateOptions.isNotEmpty && vm.hours > 0;

    String? estimateDisplay;
    String? breakdownText;
    if (hasExactEstimate) {
      final total = (vm.selectedRate!.hourlyRate * Decimal.fromInt(vm.hours)).toStringAsFixed(2);
      estimateDisplay = '\$$total';
      breakdownText = '${vm.hours} ${vm.hours == 1 ? 'hour' : 'hours'} × \$${vm.selectedRate!.hourlyRate.toStringAsFixed(2)} / hour';
    } else if (hasRange) {
      final rates = vm.rateOptions.map((r) => r.hourlyRate).toList()..sort();
      final minTotal = (rates.first * Decimal.fromInt(vm.hours)).toStringAsFixed(2);
      final maxTotal = (rates.last * Decimal.fromInt(vm.hours)).toStringAsFixed(2);
      if (minTotal == maxTotal) {
        estimateDisplay = '\$$minTotal';
      } else {
        estimateDisplay = '\$$minTotal – \$$maxTotal';
      }
      breakdownText = '${vm.hours} ${vm.hours == 1 ? 'hour' : 'hours'} · estimated from ${rates.length} nearby rates';
    }

    return FixoCard(
      padding: const EdgeInsets.all(Space.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated labour',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FW.semibold,
                      ),
                    ),
                    const SizedBox(height: Space.s1),
                    if (estimateDisplay != null) ...[
                      Text(
                        estimateDisplay,
                        key: const Key('job_estimate'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FW.bold,
                          color: isDark ? Colors.white : DesignTokens.brand900,
                        ),
                      ),
                      if (breakdownText != null) ...[
                        const SizedBox(height: Space.s0_5),
                        Text(
                          breakdownText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.s1),
                        child: Text(
                          'Choose a rate to see your estimate',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.receipt_long_outlined,
                color: DesignTokens.amber,
                size: 28,
              ),
            ],
          ),
          const Divider(height: 24),
          _SummaryRow(
            icon: Icons.work_outline,
            label: 'Job',
            value: vm.title.trim().isEmpty ? 'Add a job title above' : vm.title,
            isPlaceholder: vm.title.trim().isEmpty,
          ),
          const SizedBox(height: Space.s2),
          _SummaryRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: vm.resolvedAddress?.address ?? 'Choose an address result above',
            isPlaceholder: vm.resolvedAddress == null,
          ),
          if (vm.scheduledStartLocal != null) ...[
            const SizedBox(height: Space.s2),
            _SummaryRow(
              icon: Icons.calendar_today_outlined,
              label: 'When',
              value: '${MaterialLocalizations.of(context).formatFullDate(vm.scheduledStartLocal!)} · '
                  '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(vm.scheduledStartLocal!))}',
            ),
          ],
          const SizedBox(height: Space.s3),
          Text(
            'Materials are not included and are settled directly with the tradie. The server confirms the total when you post.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: DesignTokens.fontSizeCaption,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isPlaceholder;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Space.s0_5, right: Space.s2),
          child: Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FW.semibold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isPlaceholder
                        ? theme.hintColor
                        : theme.colorScheme.onSurface,
                    fontStyle:
                        isPlaceholder ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Photo grid widget ─────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  final List<String> paths;
  final VoidCallback onAdd;
  final void Function(String path) onRemove;

  const _PhotoGrid({
    required this.paths,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final path in paths)
          _PhotoThumbnail(path: path, onRemove: () => onRemove(path)),
        if (paths.length < 5)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(
                  style: BorderStyle.solid,
                  color: theme.dividerColor,
                ),
                borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Space.s1),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 24,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: Space.s1),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeCaption,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  const _PhotoThumbnail({required this.path, required this.onRemove});

  bool get _isAsset => path.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final image = _isAsset
        ? Image.asset(
            path,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => Container(
              width: 80,
              height: 80,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.image_outlined),
            ),
          )
        : Image.file(
            File(path),
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => Container(
              width: 80,
              height: 80,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.image_outlined),
            ),
          );
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
          child: image,
        ),
        Positioned(
          top: 2,
          right: 2,
          child: IconButton.filledTonal(
            onPressed: onRemove,
            tooltip: 'Remove photo',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.close, size: 20),
          ),
        ),
      ],
    );
  }
}

class _AddressField extends ConsumerStatefulWidget {
  const _AddressField();

  @override
  ConsumerState<_AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends ConsumerState<_AddressField> {
  late final TextEditingController _controller;
  bool _userHasEdited = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(postJobProvider).address,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When the ViewModel loads a cached address asynchronously, update the
    // controller — but only if the user hasn't started typing yet.
    ref.listen<PostJobState>(postJobProvider, (prev, next) {
      if (!_userHasEdited &&
          next.address.isNotEmpty &&
          _controller.text != next.address) {
        _controller.text = next.address;
        _controller.selection = TextSelection.collapsed(
          offset: next.address.length,
        );
      }
    });

    final search = ref.watch(addressSearchProvider);
    final job = ref.watch(postJobProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('address_search_field'),
          controller: _controller,
          maxLength: 160,
          buildCounter: _hideCounterUntilThreshold(threshold: 0.8),
          decoration: const InputDecoration(
            labelText: 'Job address',
            hintText: 'Start with the street number and road name',
            prefixIcon: Icon(Icons.location_on_outlined),
            helperText: 'Select a result to confirm the job location.',
            helperMaxLines: 3,
          ),
          onChanged: (value) {
            _userHasEdited = true;
            ref.read(postJobProvider.notifier).setAddress(value);
            ref.read(addressSearchProvider.notifier).edit(value);
          },
        ),
        if (search.loading)
          const Padding(
            padding: EdgeInsets.all(Space.s3),
            child: LinearProgressIndicator(
              semanticsLabel: 'Searching addresses',
            ),
          ),
        if (search.error != null) ...[
          Text(
            search.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: ref.read(addressSearchProvider.notifier).retry,
            child: const Text('Retry address search'),
          ),
        ],
        if (search.searched && search.result!.items.isEmpty)
          const Text(
            'No matching addresses. Check the street number and spelling, or add the town or city.',
          ),
        for (final address in search.result?.items ?? [])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(address.address),
            minVerticalPadding: 16,
            onTap: () {
              _userHasEdited = false;
              _controller.text = address.address;
              ref
                  .read(postJobProvider.notifier)
                  .selectAddress(
                    address,
                    '${search.result!.attribution}\n${search.result!.attributionUrl}',
                  );
              ref.read(addressSearchProvider.notifier).clear();
              FocusScope.of(context).unfocus();
            },
          ),
        if (job.resolvedAddress != null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.s2),
            child: Text(
              'Address selected',
              semanticsLabel: 'Job address selected',
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FW.semibold),
      ),
    );
  }
}
