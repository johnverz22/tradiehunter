import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'ho_post_job_mapper.dart';
import 'ho_service_sheet.dart';

class HoPostJobBasics extends ConsumerStatefulWidget {
  const HoPostJobBasics({super.key});

  @override
  ConsumerState<HoPostJobBasics> createState() => _HoPostJobBasicsState();
}

class _HoPostJobBasicsState extends ConsumerState<HoPostJobBasics> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _hours;
  final _titleFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  final _hoursFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final state = ref.read(postJobProvider);
    _title = TextEditingController(text: state.title);
    _description = TextEditingController(text: state.description);
    _hours = TextEditingController(
      text: state.estimatedHours == null
          ? ''
          : thFormatHours(state.estimatedHours!),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _hours.dispose();
    _titleFocus.dispose();
    _descriptionFocus.dispose();
    _hoursFocus.dispose();
    super.dispose();
  }

  void _sync(TextEditingController controller, FocusNode focus, String value) {
    if (focus.hasFocus || controller.text == value) return;
    controller.text = value;
    controller.selection = TextSelection.collapsed(offset: value.length);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PostJobState>(postJobProvider, (previous, next) {
      _sync(_title, _titleFocus, next.title);
      _sync(_description, _descriptionFocus, next.description);
      _sync(
        _hours,
        _hoursFocus,
        next.estimatedHours == null ? '' : thFormatHours(next.estimatedHours!),
      );
    });

    final state = ref.watch(postJobProvider);
    final notifier = ref.read(postJobProvider.notifier);
    final copy = thPostJobCopy(state.jobType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeControl(selected: state.jobType, onSelected: notifier.setJobType),
        const SizedBox(height: Space.s2),
        THText(copy.modeHint, style: THTextStyle.meta, tone: THTone.soft),
        const SizedBox(height: Space.s5),
        THText(
          'WHAT DO YOU NEED?',
          style: THTextStyle.label,
          tone: THTone.soft,
        ),
        const SizedBox(height: Space.s2),
        THTextField(
          key: const Key('title_field'),
          label: copy.titleLabel,
          hint: copy.titleHint,
          controller: _title,
          focusNode: _titleFocus,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(thTitleMaxLength)],
          onChanged: notifier.setTitle,
          onFieldSubmitted: (_) => _descriptionFocus.requestFocus(),
        ),
        if (thShowCounter(state.title.length, thTitleMaxLength))
          _Counter(length: state.title.length, max: thTitleMaxLength),
        const SizedBox(height: Space.s3),
        _ServiceField(
          services: state.services,
          selected: state.selectedService,
          loading: state.isLoadingServices,
          onRetry: notifier.loadServices,
          onSelected: notifier.selectService,
        ),
        const SizedBox(height: Space.s3),
        THTextField(
          key: const Key('description_field'),
          label: copy.descriptionLabel,
          hint: copy.descriptionHint,
          controller: _description,
          focusNode: _descriptionFocus,
          minLines: 5,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [
            LengthLimitingTextInputFormatter(thDescriptionMaxLength),
          ],
          onChanged: notifier.setDescription,
          onFieldSubmitted: (_) => _hoursFocus.requestFocus(),
        ),
        if (thShowCounter(state.description.length, thDescriptionMaxLength))
          _Counter(
            length: state.description.length,
            max: thDescriptionMaxLength,
          ),
        if (state.error != null && state.error!.contains('description'))
          Padding(
            padding: const EdgeInsets.only(top: Space.s1),
            child: THText(
              state.error!,
              style: THTextStyle.meta,
              tone: THTone.danger,
            ),
          ),
        const SizedBox(height: Space.s3),
        THTextField(
          key: const Key('hours_field'),
          label: 'ESTIMATED HOURS · OPTIONAL',
          hint: 'Blank means total is confirmed on completion',
          controller: _hours,
          focusNode: _hoursFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onChanged: notifier.setEstimatedHours,
        ),
        const SizedBox(height: Space.s1),
        THText(
          'Skip if unsure — total is confirmed when the job is done.',
          style: THTextStyle.meta,
          tone: THTone.soft,
        ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.length, required this.max});

  final int length;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: Space.s1),
        child: THText(
          '$length / $max',
          style: THTextStyle.meta,
          tone: THTone.soft,
        ),
      ),
    );
  }
}

class _ModeControl extends StatelessWidget {
  const _ModeControl({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final project = selected == Job.jobTypeProject;
    return Stack(
      children: [
        THSegmented(
          items: const ['Quick job · hourly', 'Project'],
          selected: project ? 1 : 0,
        ),
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  selected: !project,
                  label: 'Quick job hourly',
                  child: GestureDetector(
                    key: const Key('job_type_${Job.jobTypeHourly}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(Job.jobTypeHourly),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: project,
                  label: 'Project',
                  child: GestureDetector(
                    key: const Key('job_type_${Job.jobTypeProject}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(Job.jobTypeProject),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceField extends StatelessWidget {
  const _ServiceField({
    required this.services,
    required this.selected,
    required this.loading,
    required this.onRetry,
    required this.onSelected,
  });

  final List<ServiceOption> services;
  final ServiceOption? selected;
  final bool loading;
  final VoidCallback onRetry;
  final ValueChanged<ServiceOption> onSelected;

  void _open(BuildContext context) {
    showThServiceSheet(context, services: services, selected: selected).then((
      picked,
    ) {
      if (picked != null && context.mounted) onSelected(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Choose a service',
          child: InkWell(
            key: const Key('service_dropdown'),
            onTap: services.isEmpty ? null : () => _open(context),
            borderRadius: BorderRadius.circular(Radii.control),
            child: THField(
              label: 'SERVICE',
              value: selected?.name ?? 'Choose a service',
              placeholder: selected == null,
              trailing: Icons.chevron_right_rounded,
            ),
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: Space.s2),
            child: LinearProgressIndicator(semanticsLabel: 'Loading services'),
          ),
        if (!loading && services.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.s2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: THButton(
                label: 'Retry loading services',
                kind: THButtonKind.ghost,
                size: THButtonSize.sm,
                fullWidth: false,
                onPressed: onRetry,
              ),
            ),
          ),
      ],
    );
  }
}
