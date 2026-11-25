import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../repositories/chat_reviews_repository.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import 'th_sheet_chrome.dart';

/// Scheduling bottom sheet (M4-08), v2 skin.
///
/// Shows the current schedule status and lets the user propose / confirm a
/// day and a Morning / Afternoon / Evening slot. The date picker's minimum is
/// tomorrow.
class ThScheduleSheet extends ConsumerStatefulWidget {
  const ThScheduleSheet({super.key, required this.jobId});

  final String jobId;

  /// Opens the scheduling sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context, {required String jobId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ThScheduleSheet(jobId: jobId),
    );
  }

  @override
  ConsumerState<ThScheduleSheet> createState() => _ThScheduleSheetState();
}

class _ThScheduleSheetState extends ConsumerState<ThScheduleSheet> {
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
        await Future<void>.delayed(THDurations.sheetDelayLong);
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() => _isSending = false);
        THNotice.error(context, 'Could not save schedule. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ThScope(
      child: Builder(
        builder: (context) {
          final c = context.th;
          final dateFormat = DateFormat('EEE, d MMM yyyy');
          final status = _existing?.scheduleStatus;
          return ThSheetFrame(
            child: _loadingExisting
                ? const SizedBox(
                    height: Sizes.avatarLg * 2,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _success
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: Space.s3,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: c.success,
                        size: Sizes.avatarLg,
                      ),
                      THText(
                        status == 'Confirmed'
                            ? 'Schedule confirmed!'
                            : 'Schedule proposed!',
                        style: THTextStyle.h2,
                        align: TextAlign.center,
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: Space.s3,
                    children: [
                      const THText('Schedule Job', style: THTextStyle.h2),
                      if (status != null && status != 'None')
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: THBadge(
                            status == 'Confirmed'
                                ? 'Schedule confirmed'
                                : 'Schedule proposed',
                            kind: status == 'Confirmed'
                                ? THBadgeKind.ok
                                : THBadgeKind.accent,
                          ),
                        ),
                      const THText('Select date', style: THTextStyle.label),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(Radii.control),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.s4,
                            vertical: Space.s3_5,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: c.line),
                            borderRadius: BorderRadius.circular(Radii.control),
                          ),
                          child: Row(
                            spacing: Space.s3,
                            children: [
                              THIcon(Icons.calendar_today, tone: THTone.soft),
                              THText(
                                _selectedDate != null
                                    ? dateFormat.format(_selectedDate!)
                                    : 'Pick a date…',
                                tone: _selectedDate != null
                                    ? THTone.base
                                    : THTone.soft,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const THText('Preferred time', style: THTextStyle.label),
                      Row(
                        spacing: Space.s2,
                        children: [
                          for (final slot in _slots)
                            Expanded(
                              child: _SlotChip(
                                icon: _slotIcons[slot]!,
                                label: slot,
                                hours: _slotLabels[slot]!,
                                selected: _selectedSlot == slot,
                                onTap: () =>
                                    setState(() => _selectedSlot = slot),
                              ),
                            ),
                        ],
                      ),
                      THButton(
                        label:
                            status == 'Proposed' &&
                                _existing?.proposedByUserId != null
                            ? 'Confirm Schedule'
                            : 'Propose Schedule',
                        kind: THButtonKind.accent,
                        loading: _isSending,
                        onPressed:
                            (_selectedDate == null ||
                                _selectedSlot == null ||
                                _isSending)
                            ? null
                            : _submit,
                      ),
                      THButton(
                        label: 'Cancel',
                        kind: THButtonKind.ghost,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.icon,
    required this.label,
    required this.hours,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hours;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $hours',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: AnimatedContainer(
          duration: THDurations.fast,
          padding: const EdgeInsets.symmetric(
            vertical: Space.s3,
            horizontal: Space.s2,
          ),
          decoration: BoxDecoration(
            color: selected ? c.accentTint : c.surfaceAlt,
            border: Border.all(
              color: selected ? c.accent : Colors.transparent,
              width: selected ? 1.5 : 0,
            ),
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          child: Column(
            spacing: Space.s1,
            children: [
              THIcon(icon, tone: selected ? THTone.accent : THTone.soft),
              THText(
                label,
                style: THTextStyle.meta,
                tone: selected ? THTone.accent : THTone.soft,
                bold: selected,
              ),
              THText(hours, style: THTextStyle.meta, tone: THTone.soft),
            ],
          ),
        ),
      ),
    );
  }
}
