import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/jobs_viewmodel.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../shared/th_choice_pills.dart';
import 'ho_post_job_mapper.dart';

const List<String> _urgencies = ['Low', 'Medium', 'High', 'Emergency'];

class HoPostJobTiming extends ConsumerWidget {
  const HoPostJobTiming({super.key});

  Future<DateTime?> _pickDateTime(
    BuildContext context, {
    DateTime? initial,
  }) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: initial ?? now,
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.now(),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _pickStart(BuildContext context, WidgetRef ref, DateTime? initial) {
    _pickDateTime(context, initial: initial).then((picked) {
      if (picked == null || !context.mounted) return;
      ref.read(postJobProvider.notifier).setScheduledStartLocal(picked);
    });
  }

  void _pickEnd(BuildContext context, WidgetRef ref, DateTime? initial) {
    _pickDateTime(context, initial: initial).then((picked) {
      if (picked == null || !context.mounted) return;
      ref.read(postJobProvider.notifier).setScheduledEndLocal(picked);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(postJobProvider);
    final notifier = ref.read(postJobProvider.notifier);
    final options = thTimingOptions(state.jobType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        THText(
          'WHEN DO YOU NEED HELP?',
          style: THTextStyle.label,
          tone: THTone.soft,
        ),
        const SizedBox(height: Space.s2),
        ThChoicePills(
          singleRow: true,
          items: [
            for (final option in options)
              ThChoicePillItem(
                label: option.label,
                icon: option.icon,
                selected: state.timingPreference == option.wireValue,
                onSelected: () =>
                    notifier.setTimingPreference(option.wireValue),
              ),
          ],
        ),
        const SizedBox(height: Space.s2),
        THText(
          thTimingHelper(state.timingPreference),
          style: THTextStyle.meta,
          tone: THTone.soft,
        ),
        if (state.timingPreference == 'SpecificDate') ...[
          const SizedBox(height: Space.s3),
          _DatePickRow(
            key: const Key('scheduled_start_field'),
            label: 'START',
            value: state.scheduledStartLocal == null
                ? 'Choose a start date and time'
                : _format(context, state.scheduledStartLocal!),
            placeholder: state.scheduledStartLocal == null,
            onTap: () => _pickStart(context, ref, state.scheduledStartLocal),
          ),
        ],
        if (state.timingPreference == 'DateRange') ...[
          const SizedBox(height: Space.s3),
          _DatePickRow(
            key: const Key('scheduled_start_field'),
            label: 'START',
            value: state.scheduledStartLocal == null
                ? 'Choose a start date and time'
                : _format(context, state.scheduledStartLocal!),
            placeholder: state.scheduledStartLocal == null,
            onTap: () => _pickStart(context, ref, state.scheduledStartLocal),
          ),
          const SizedBox(height: Space.s2),
          _DatePickRow(
            key: const Key('scheduled_end_field'),
            label: 'END',
            value: state.scheduledEndLocal == null
                ? 'Choose an end date and time'
                : _format(context, state.scheduledEndLocal!),
            placeholder: state.scheduledEndLocal == null,
            onTap: () => _pickEnd(
              context,
              ref,
              state.scheduledEndLocal ?? state.scheduledStartLocal,
            ),
          ),
        ],
      ],
    );
  }

  String _format(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value));
    return '${localizations.formatFullDate(value)} · $time';
  }
}

/// Urgency pills. Kept (G-8..G-12) but not part of the mockup's field list, so
/// the screen shows it in the "More details" group after the mockup fields.
class HoPostJobUrgency extends ConsumerWidget {
  const HoPostJobUrgency({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(postJobProvider);
    final notifier = ref.read(postJobProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        THText('URGENCY', style: THTextStyle.label, tone: THTone.soft),
        const SizedBox(height: Space.s2),
        ThChoicePills(
          items: [
            for (final urgency in _urgencies)
              ThChoicePillItem(
                label: urgency,
                selected: state.urgency == urgency,
                onSelected: () => notifier.setUrgency(urgency),
              ),
          ],
        ),
        const SizedBox(height: Space.s2),
        THText(
          thUrgencyMeaning(state.urgency),
          style: THTextStyle.meta,
          tone: THTone.soft,
        ),
      ],
    );
  }
}

class _DatePickRow extends StatelessWidget {
  const _DatePickRow({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      identifier: thTestId(key),
      label: '$label date and time',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: THField(
          label: label,
          value: value,
          icon: Icons.event_outlined,
          trailing: Icons.arrow_drop_down,
          placeholder: placeholder,
        ),
      ),
    );
  }
}
