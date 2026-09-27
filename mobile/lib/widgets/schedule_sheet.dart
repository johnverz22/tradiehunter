import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../repositories/chat_reviews_repository.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';

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
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not save schedule. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('EEE, d MMM yyyy');

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? DesignTokens.paperLineDark
                          : DesignTokens.paperLineLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Success state
                if (_success) ...[
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle,
                            color: DesignTokens.green, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _existing?.scheduleStatus == 'Confirmed'
                              ? 'Schedule confirmed!'
                              : 'Schedule proposed!',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // Header
                  Text(
                    'Schedule Job',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),

                  // Current status pill
                  if (_existing != null &&
                      _existing!.scheduleStatus != 'None') ...[
                    const SizedBox(height: 8),
                    _StatusPill(
                        status: _existing!.scheduleStatus,
                        isDark: isDark,
                        theme: theme),
                    const SizedBox(height: 4),
                  ],

                  const SizedBox(height: 16),

                  // Date picker button
                  Text(
                    'Select Date',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(DesignTokens.radius),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark
                              ? DesignTokens.paperLineDark
                              : DesignTokens.paperLineLight,
                        ),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radius),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
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
                  const SizedBox(height: 20),

                  // Time slot selector
                  Text(
                    'Preferred Time',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _slots.map((slot) {
                      final selected = _selectedSlot == slot;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: slot == _slots.last ? 0 : 8,
                          ),
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedSlot = slot),
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radius),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? DesignTokens.amber
                                        .withValues(alpha: 0.15)
                                    : (isDark
                                        ? DesignTokens.brand100Dark
                                        : DesignTokens.brand100Light),
                                border: Border.all(
                                  color: selected
                                      ? DesignTokens.amber
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(
                                    DesignTokens.radius),
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
                                  const SizedBox(height: 4),
                                  Text(
                                    slot,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: selected
                                          ? DesignTokens.amber
                                          : theme
                                              .colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    _slotLabels[slot]!,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: theme
                                          .colorScheme.onSurfaceVariant,
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
                  const SizedBox(height: 24),

                  // Propose / Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: (_selectedDate == null ||
                              _selectedSlot == null ||
                              _isSending)
                          ? null
                          : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignTokens.amber,
                        foregroundColor: const Color(0xFF241300),
                        disabledBackgroundColor: isDark
                            ? DesignTokens.paperLineDark
                            : DesignTokens.paperLineLight,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _existing?.scheduleStatus == 'Proposed' &&
                                      _existing?.proposedByUserId != null
                                  ? 'Confirm Schedule'
                                  : 'Propose Schedule',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
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

class _StatusPill extends StatelessWidget {
  final String status;
  final bool isDark;
  final ThemeData theme;

  const _StatusPill({
    required this.status,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isConfirmed = status == 'Confirmed';
    final color =
        isConfirmed ? DesignTokens.green : DesignTokens.amber;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        isConfirmed ? '✓ Schedule Confirmed' : '⏳ Schedule Proposed',
        style: TextStyle(
          fontFamily: DesignTokens.fontMono,
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
