// Structured quote form for the v2 tradie request detail (`tr_lead`, plan
// 5.2). Port of v1 `_QuoteFormSheet` (contract #12): pricing model with the
// matching amount fields, inclusions/exclusions, materials + GST flags,
// proposed start and duration. Pops a ready-to-POST payload map (built by
// [TrQuoteDraft.toPayload], the v1 rules) or null when dismissed.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart' show Quote;
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../shared/th_choice_pills.dart';
import 'tr_lead_mapper.dart';

/// Opens the quote sheet. The sheet route sits above the screen's
/// [ThScope], so the scope is re-applied here.
Future<Map<String, dynamic>?> showTrQuoteSheet(
  BuildContext context, {
  required ThemeMode themeMode,
  required bool? gstRegisteredFromProfile,
  int? quoteValidityHours,
}) => showModalBottomSheet<Map<String, dynamic>>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  backgroundColor: Colors.transparent,
  builder: (_) => ThScope(
    themeMode: themeMode,
    child: TrQuoteSheet(
      gstRegisteredFromProfile: gstRegisteredFromProfile,
      quoteValidityHours: quoteValidityHours,
    ),
  ),
);

class TrQuoteSheet extends StatefulWidget {
  const TrQuoteSheet({
    super.key,
    required this.gstRegisteredFromProfile,
    this.quoteValidityHours,
  });

  /// The tradie's profile GST registration, when known.
  final bool? gstRegisteredFromProfile;

  /// Server-configured quote validity window in hours (Q4.2 / Q7.10).
  /// Omitted when unknown — never hard-coded.
  final int? quoteValidityHours;

  @override
  State<TrQuoteSheet> createState() => _TrQuoteSheetState();
}

class _TrQuoteSheetState extends State<TrQuoteSheet> {
  final _amount = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _rate = TextEditingController();
  final _cap = TextEditingController();
  final _inclusions = TextEditingController();
  final _exclusions = TextEditingController();
  final _duration = TextEditingController();

  String _pricingModel = Quote.pricingFixed;
  bool _materialsIncluded = false;
  late bool _gstIncluded = widget.gstRegisteredFromProfile ?? false;
  DateTime? _proposedStart;

  @override
  void dispose() {
    for (final c in [
      _amount,
      _min,
      _max,
      _rate,
      _cap,
      _inclusions,
      _exclusions,
      _duration,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  TrQuoteDraft get _draft => TrQuoteDraft(
    pricingModel: _pricingModel,
    amount: _amount.text,
    min: _min.text,
    max: _max.text,
    rate: _rate.text,
    cap: _cap.text,
    inclusions: _inclusions.text,
    exclusions: _exclusions.text,
    duration: _duration.text,
    materialsIncluded: _materialsIncluded,
    gstIncluded: _gstIncluded,
    proposedStart: _proposedStart,
  );

  void _refresh(String _) => setState(() {});

  void _submit() {
    final payload = _draft.toPayload();
    if (payload != null) Navigator.of(context).pop(payload);
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDate: _proposedStart ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_proposedStart ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _proposedStart = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.th.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Sizes.gutter,
            Space.s5,
            Sizes.gutter,
            MediaQuery.viewInsetsOf(context).bottom + Space.s5,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Space.s3,
              children: [
                const THText('Submit quote', style: THTextStyle.h2),
                THText(
                  widget.quoteValidityHours != null
                      ? 'The homeowner compares quotes side by side — price, scope '
                          'and timing all show on your card. Valid for ${widget.quoteValidityHours} hours.'
                      : 'The homeowner compares quotes side by side — price, scope '
                          'and timing all show on your card.',
                  style: THTextStyle.meta,
                  tone: THTone.soft,
                ),
                const THText(
                  'How do you want to price this job?',
                  style: THTextStyle.title,
                ),
                ThChoicePills(
                  items: [
                    for (final option in trQuotePricingOptions)
                      ThChoicePillItem(
                        key: ValueKey<String>('quote_pricing_${option.$1}'),
                        label: option.$2,
                        selected: _pricingModel == option.$1,
                        onSelected: () =>
                            setState(() => _pricingModel = option.$1),
                      ),
                  ],
                ),
                ..._amountFields(draft),
                THTextField(
                  key: const Key('quote_inclusions_field'),
                  controller: _inclusions,
                  label: 'Inclusions (optional)',
                  hint: 'What the price covers…',
                  minLines: 3,
                  maxLines: 3,
                  maxLength: 1000,
                  keyboardType: TextInputType.multiline,
                  onChanged: _refresh,
                ),
                THTextField(
                  key: const Key('quote_exclusions_field'),
                  controller: _exclusions,
                  label: 'Exclusions (optional)',
                  hint: 'What it does not cover…',
                  minLines: 3,
                  maxLines: 3,
                  maxLength: 1000,
                  keyboardType: TextInputType.multiline,
                  onChanged: _refresh,
                ),
                _SwitchRow(
                  switchKey: const Key('quote_materials_switch'),
                  label: 'Materials included in the price',
                  on: _materialsIncluded,
                  onChanged: (v) => setState(() => _materialsIncluded = v),
                ),
                _SwitchRow(
                  switchKey: const Key('quote_gst_switch'),
                  label: 'Quote includes GST',
                  on: _gstIncluded,
                  // The server rejects a GST flag that disagrees with the
                  // profile, so lock the switch when the profile is known.
                  enabled: widget.gstRegisteredFromProfile == null,
                  onChanged: (v) => setState(() => _gstIncluded = v),
                ),
                THText(
                  trGstHelper(
                    fromProfile: widget.gstRegisteredFromProfile,
                    included: _gstIncluded,
                  ),
                  style: THTextStyle.meta,
                  tone: THTone.soft,
                ),
                _StartField(start: _proposedStart, onTap: _pickStart),
                THTextField(
                  key: const Key('quote_duration_field'),
                  controller: _duration,
                  label: 'Estimated duration in days (optional)',
                  hint: 'e.g. 3',
                  keyboardType: TextInputType.number,
                  onChanged: _refresh,
                ),
                THButton(
                  key: const Key('quote_submit_button'),
                  label: 'Send quote',
                  kind: THButtonKind.accent,
                  onPressed: draft.canSubmit ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _amountFields(TrQuoteDraft draft) => switch (_pricingModel) {
    Quote.pricingFixed => [
      THTextField(
        key: const Key('quote_amount_field'),
        controller: _amount,
        label: 'Total price (\$)',
        hint: 'The all-up price for the whole job',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: _refresh,
      ),
    ],
    Quote.pricingEstimateRange => [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.s3,
        children: [
          Expanded(
            child: THTextField(
              key: const Key('quote_min_field'),
              controller: _min,
              label: 'Estimate min (\$)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: _refresh,
            ),
          ),
          Expanded(
            child: THTextField(
              key: const Key('quote_max_field'),
              controller: _max,
              label: 'Estimate max (\$)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: _refresh,
            ),
          ),
        ],
      ),
      if (draft.rangeInverted)
        const THText(
          'The minimum must not exceed the maximum.',
          style: THTextStyle.meta,
          tone: THTone.danger,
        ),
    ],
    _ => [
      THTextField(
        key: const Key('quote_rate_field'),
        controller: _rate,
        label: 'Hourly rate (\$)',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: _refresh,
      ),
      THTextField(
        key: const Key('quote_cap_field'),
        controller: _cap,
        label: 'Cap — maximum total (\$)',
        hint: 'The homeowner pays your rate, never more than the cap.',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: _refresh,
      ),
      if (draft.capBelowRate)
        const THText(
          'The cap must be at least your hourly rate.',
          style: THTextStyle.meta,
          tone: THTone.danger,
        ),
    ],
  };
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.switchKey,
    required this.label,
    required this.on,
    required this.onChanged,
    this.enabled = true,
  });

  final Key switchKey;
  final String label;
  final bool on;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    spacing: Space.s3,
    children: [
      Expanded(child: THText(label, style: THTextStyle.body)),
      Semantics(
        label: label,
        child: IgnorePointer(
          ignoring: !enabled,
          child: Opacity(
            opacity: enabled ? 1 : 0.6,
            child: THSwitch(key: switchKey, on: on, onChanged: onChanged),
          ),
        ),
      ),
    ],
  );
}

class _StartField extends StatelessWidget {
  const _StartField({required this.start, required this.onTap});

  final DateTime? start;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final text = start == null
        ? 'Proposed start (optional)'
        : '${DateFormat('EEE d MMM y').format(start!)} · '
              '${DateFormat('h:mm a').format(start!)}';
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: InkWell(
        key: const Key('quote_start_field'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: Sizes.input),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s4,
            vertical: Space.s2,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(color: c.line),
          ),
          child: Row(
            spacing: Space.s3,
            children: [
              const THIcon(Icons.event_outlined, tone: THTone.soft),
              Expanded(
                child: THText(
                  text,
                  style: THTextStyle.body,
                  tone: start == null ? THTone.soft : THTone.base,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
