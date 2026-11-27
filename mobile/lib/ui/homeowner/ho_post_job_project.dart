import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/jobs_viewmodel.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../shared/th_choice_pills.dart';
import 'ho_post_job_mapper.dart';

class HoPostJobProject extends ConsumerStatefulWidget {
  const HoPostJobProject({super.key});

  @override
  ConsumerState<HoPostJobProject> createState() => _HoPostJobProjectState();
}

class _HoPostJobProjectState extends ConsumerState<HoPostJobProject> {
  late final TextEditingController _budgetMin;
  late final TextEditingController _budgetMax;
  late final TextEditingController _scopeNotes;
  final _budgetMinFocus = FocusNode();
  final _budgetMaxFocus = FocusNode();
  final _scopeNotesFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final state = ref.read(postJobProvider);
    _budgetMin = TextEditingController(text: state.budgetMin?.toString() ?? '');
    _budgetMax = TextEditingController(text: state.budgetMax?.toString() ?? '');
    _scopeNotes = TextEditingController(text: state.scopeNotes);
  }

  @override
  void dispose() {
    _budgetMin.dispose();
    _budgetMax.dispose();
    _scopeNotes.dispose();
    _budgetMinFocus.dispose();
    _budgetMaxFocus.dispose();
    _scopeNotesFocus.dispose();
    super.dispose();
  }

  void _sync(TextEditingController controller, FocusNode focus, String value) {
    if (focus.hasFocus || controller.text == value) return;
    controller.text = value;
    controller.selection = TextSelection.collapsed(offset: value.length);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postJobProvider);
    if (!state.isProject) return const SizedBox.shrink();

    ref.listen<PostJobState>(postJobProvider, (previous, next) {
      _sync(_budgetMin, _budgetMinFocus, next.budgetMin?.toString() ?? '');
      _sync(_budgetMax, _budgetMaxFocus, next.budgetMax?.toString() ?? '');
      _sync(_scopeNotes, _scopeNotesFocus, next.scopeNotes);
    });

    final notifier = ref.read(postJobProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        THText(
          'WHO CAN QUOTE?',
          style: THTextStyle.label,
          tone: THTone.soft,
        ),
        const SizedBox(height: Space.s2),
        ThChoicePills(
          items: [
            ThChoicePillItem(
              key: const Key('post_project_open_board_pill'),
              label: 'Open to nearby tradies',
              selected: state.openToBoard,
              onSelected: () => notifier.setOpenToBoard(true),
            ),
            ThChoicePillItem(
              key: const Key('post_project_invite_pill'),
              label: 'Invite tradies',
              selected: !state.openToBoard,
              onSelected: () => notifier.setOpenToBoard(false),
            ),
          ],
        ),
        const SizedBox(height: Space.s2),
        THText(
          state.openToBoard
              ? 'Nearby qualified tradies can see your project and send quotes.'
              : 'You pick up to 3 specific tradies to request quotes from.',
          style: THTextStyle.meta,
          tone: THTone.soft,
        ),
        const SizedBox(height: Space.s4),
        THText(
          'PROJECT DETAILS · OPTIONAL',
          style: THTextStyle.label,
          tone: THTone.soft,
        ),
        const SizedBox(height: Space.s2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: THTextField(
                key: const Key('budget_min_field'),
                label: 'BUDGET MIN',
                hint: 'e.g. 15000',
                icon: Icons.attach_money,
                controller: _budgetMin,
                focusNode: _budgetMinFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: notifier.setBudgetMin,
                onFieldSubmitted: (_) => _budgetMaxFocus.requestFocus(),
              ),
            ),
            const SizedBox(width: Space.s3),
            Expanded(
              child: THTextField(
                key: const Key('budget_max_field'),
                label: 'BUDGET MAX',
                hint: 'e.g. 25000',
                icon: Icons.attach_money,
                controller: _budgetMax,
                focusNode: _budgetMaxFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: notifier.setBudgetMax,
                onFieldSubmitted: (_) => _scopeNotesFocus.requestFocus(),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.s4),
        THText(
          'WHO BUYS THE MATERIALS?',
          style: THTextStyle.label,
          tone: THTone.soft,
        ),
        const SizedBox(height: Space.s2),
        ThChoicePills(
          items: [
            for (final option in postJobMaterialsOptions)
              ThChoicePillItem(
                label: option.$2,
                selected: state.materialsBy == option.$1,
                onSelected: () => notifier.setMaterialsBy(option.$1),
              ),
          ],
        ),
        const SizedBox(height: Space.s4),
        Semantics(
          button: true,
          toggled: state.siteVisitWelcome,
          identifier: 'site_visit_switch',
          label: 'Site visit welcome',
          child: InkWell(
            key: const Key('site_visit_switch'),
            onTap: () => notifier.setSiteVisitWelcome(!state.siteVisitWelcome),
            borderRadius: BorderRadius.circular(Radii.control),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        THText('Site visit welcome', style: THTextStyle.title),
                        const SizedBox(height: Space.s1),
                        THText(
                          'Tradies can ask to look at the job before quoting.',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.s3),
                  THSwitch(on: state.siteVisitWelcome),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.s3),
        THTextField(
          key: const Key('scope_notes_field'),
          label: 'SCOPE NOTES · OPTIONAL',
          hint: 'What is in scope, what is not…',
          controller: _scopeNotes,
          focusNode: _scopeNotesFocus,
          minLines: 4,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [
            LengthLimitingTextInputFormatter(thScopeNotesMaxLength),
          ],
          onChanged: notifier.setScopeNotes,
        ),
        if (thShowCounter(state.scopeNotes.length, thScopeNotesMaxLength))
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: Space.s1),
              child: THText(
                '${state.scopeNotes.length} / $thScopeNotesMaxLength',
                style: THTextStyle.meta,
                tone: THTone.soft,
              ),
            ),
          ),
        const SizedBox(height: Space.s4),
        THCard(
          tone: THCardTone.accent,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.s2_5,
              children: [
                const THIcon(
                  Icons.info_outline_rounded,
                  size: Sizes.iconLg,
                  tone: THTone.accent,
                ),
                Expanded(
                  child: THText(
                    'Jobs over \$30,000 need a written contract. '
                    'Milestone payments are not available yet.',
                    style: THTextStyle.meta,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
