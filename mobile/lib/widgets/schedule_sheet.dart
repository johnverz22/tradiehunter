import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../repositories/chat_reviews_repository.dart';
import '../../theme/design_tokens.dart';
import '../views/widgets/fixo_feedback.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../feedback/fixo_notice.dart';

/// Scheduling bottom sheet (M4-08).
/// Shows current schedule status and allows proposal/confirmation.
///
/// Time slot selector: Morning / Afternoon / Evening (custom chips).
/// Date picker: Flutter's [showDatePicker] with minimum = tomorrow.
class ScheduleSheet extends ConsumerStatefulWidget {
  final String jobId;

  const ScheduleSheet({super.key, required this.jobId});

  /// Opens the scheduling sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context, {required String jobId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleSheet(jobId: jobId),
    );
  }

  @override
  ConsumerState<ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends ConsumerState<ScheduleSheet> {
  DateTime? _selectedDate;
  String? _selectedSlot; // 'Morning' | 'Afternoon' | 'Evening'
  bool _isSending = false;
  bool _success = false;
  ScheduleInfo? _existing;
  bool _loadingExisting = true;

  static const _slots = ['Morning', 'Afternoon', 'Evening'];
  static const _slotIcons = {
    'Morning': Icons.wb_sunny_outlined,
    'Afternoon': Icons.wb_cloudy_outlined,
    'Evening': Icons.nights_stay_outlined,
  };
  static const _slotLabels = {
    'Morning': '8 am – 12 pm',
    'Afternoon': '12 pm – 5 pm',
    'Evening': '5 pm – 8 pm',
  };

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final repo = ref.read(scheduleRepositoryProvider);
    final info = await repo.getSchedule(widget.jobId);
    if (mounted) {
      setState(() {
        _existing = info;
        _loadingExisting = false;
        if (info != null && info.scheduleStatus != 'None') {
          _selectedDate = info.scheduledDateUtc;
          _selectedSlot = info.scheduledTimeSlot;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? tomorrow,
      firstDate: tomorrow,
      lastDate: tomorrow.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_selectedDate == null || _selectedSlot == null) return;
    setState(() => _isSending = true);

    final repo = ref.read(scheduleRepositoryProvider);
    final result = await repo.proposeOrConfirm(
      widget.jobId,
      proposedDateUtc: _selectedDate!.toUtc(),
      timeSlot: _selectedSlot!,
    );

    if (mounted) {
      if (result != null) {
        setState(() {
          _success = true;
          _existing = result;
          _isSending = false;
        });
        await Future<void>.delayed(FixoDurations.sheetDelayLong);
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() => _isSending = false);
        FixoNotice.error(context, 'Could not save schedule. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('EEE, d MMM yyyy');

    return Container(
      padding: EdgeInsets.fromLTRB(Space.s6, Space.s4, Space.s6, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceCard(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.tile)),
      ),
      child: _loadingExisting
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: Space.s5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? DesignTokens.paperLineDark
                          : DesignTokens.paperLineLight,
                      borderRadius: BorderRadius.circular(Radii.micro),
                    ),
                  ),
                ),

                // Success state
                if (_success) ...[
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: DesignTokens.green,
                          size: 48,
                        ),
                        const SizedBox(height: Space.s3),
                        Text(
                          _existing?.scheduleStatus == 'Confirmed'
                              ? 'Schedule confirmed!'
                              : 'Schedule proposed!',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FW.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.s6),
                ] else ...[
                  // Header
                  Text(
                    'Schedule Job',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FW.bold,
                    ),
                  ),
                  const SizedBox(height: Space.s1),

                  // Current status pill
                  if (_existing != null &&
                      _existing!.scheduleStatus != 'None') ...[
                    const SizedBox(height: Space.s2),
                    FixoPillChip(
                      label: _existing!.scheduleStatus == 'Confirmed'
                          ? '✓ Schedule Confirmed'
                          : '⏳ Schedule Proposed',
                      color: _existing!.scheduleStatus == 'Confirmed'
                          ? DesignTokens.inkSuccess(isDark)
                          : DesignTokens.inkAccent(isDark),
                    ),
                    const SizedBox(height: Space.s1),
                  ],

                  const SizedBox(height: Space.s4),

                  // Date picker button
                  Text('Select Date', style: theme.textTheme.labelLarge),
                  const SizedBox(height: Space.s2),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radiusControl,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark
                              ? DesignTokens.paperLineDark
                              : DesignTokens.paperLineLight,
                        ),
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusControl,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: Space.s3),
                          Text(
                            _selectedDate != null
                                ? dateFormat.format(_selectedDate!)
                                : 'Pick a date…',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _selectedDate != null
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s5),

                  // Time slot selector
                  Text('Preferred Time', style: theme.textTheme.labelLarge),
                  const SizedBox(height: Space.s2),
                  Row(
                    children: _slots.map((slot) {
                      final selected = _selectedSlot == slot;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: slot == _slots.last ? 0 : 8,
                          ),
                          child: InkWell(
                            onTap: () => setState(() => _selectedSlot = slot),
                            borderRadius: BorderRadius.circular(
                              DesignTokens.radiusControl,
                            ),
                            child: AnimatedContainer(
                              duration: FixoDurations.fast,
                              padding: const EdgeInsets.symmetric(vertical: Space.s3, horizontal: Space.s2),
                              decoration: BoxDecoration(
                                color: selected
                                    ? DesignTokens.amber.withValues(alpha: Alpha.tintAccent)
                                    : (isDark
                                          ? DesignTokens.brand100Dark
                                          : DesignTokens.brand100Light),
                                border: Border.all(
                                  color: selected
                                      ? DesignTokens.amber
                                      : Colors.transparent,
                                  width: DesignTokens.borderWidthFor(isDark),
                                ),
                                borderRadius: BorderRadius.circular(
                                  DesignTokens.radiusControl,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    _slotIcons[slot]!,
                                    size: 20,
                                    color: selected
                                        ? DesignTokens.amber
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: Space.s1),
                                  Text(
                                    slot,
                                    style: TextStyle(
                                      fontSize: DesignTokens.fontSizeCaption,
                                      fontWeight: selected
                                          ? FW.bold
                                          : FW.regular,
                                      color: selected
                                          ? DesignTokens.amber
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    _slotLabels[slot]!,
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
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: Space.s6),

                  // Propose / Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed:
                          (_selectedDate == null ||
                              _selectedSlot == null ||
                              _isSending)
                          ? null
                          : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignTokens.amber,
                        foregroundColor: DesignTokens.onAmber,
                        disabledBackgroundColor: isDark
                            ? DesignTokens.paperLineDark
                            : DesignTokens.paperLineLight,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _existing?.scheduleStatus == 'Proposed' &&
                                      _existing?.proposedByUserId != null
                                  ? 'Confirm Schedule'
                                  : 'Propose Schedule',
                              style: const TextStyle(
                                fontWeight: FW.semibold,
                                fontSize: DesignTokens.fontSizeBody,
                              ),
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
    );
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────

