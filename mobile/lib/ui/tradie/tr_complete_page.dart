// TrCompletePage: Full-screen v2 check-out / complete job page (plan 5.5).
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';
import '../../viewmodels/locale_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'tr_job_state.dart';

/// Launches the v2 full-screen check-out page (D-P5-2) and returns the
/// confirmed `finalHours` double, or `null` if cancelled.
Future<double?> pushTrComplete(
  BuildContext context, {
  required Job job,
  required Decimal approvedAdjustmentsTotal,
}) {
  return Navigator.of(context, rootNavigator: true).push<double?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TrCompletePage(
        job: job,
        approvedAdjustmentsTotal: approvedAdjustmentsTotal,
      ),
    ),
  );
}

class TrCompletePage extends ConsumerStatefulWidget {
  const TrCompletePage({
    super.key,
    required this.job,
    required this.approvedAdjustmentsTotal,
  });

  final Job job;
  final Decimal approvedAdjustmentsTotal;

  @override
  ConsumerState<TrCompletePage> createState() => _TrCompletePageState();
}

class _TrCompletePageState extends ConsumerState<TrCompletePage> {
  static const double _step = 0.5;
  static const double _minHours = 0.5;
  static const double _maxHours = 24.0;

  late final TextEditingController _hoursController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.job.hours > 0 ? widget.job.hours.toDouble() : 1.0;
    _hoursController = TextEditingController(text: trFormatHours(initial));
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  double? get _parsedHours {
    final parsed = double.tryParse(
      _hoursController.text.trim().replaceAll(',', '.'),
    );
    return parsed != null && parsed > 0 ? parsed : null;
  }

  void _stepHours(double delta) {
    final current = _parsedHours ?? _minHours;
    final next = (current + delta).clamp(_minHours, _maxHours);
    _hoursController.text = trFormatHours(next);
    setState(() {});
  }

  void _submit() {
    final hours = _parsedHours;
    if (hours == null || _submitting) return;
    setState(() => _submitting = true);
    Navigator.of(context).pop(hours);
  }

  @override
  Widget build(BuildContext context) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: Builder(builder: (ctx) => _page(ctx)),
  );

  Widget _page(BuildContext context) {
    final hours = _parsedHours;
    final rate = widget.job.hourlyRate;
    final labour = (hours != null && rate != null)
        ? trLabourPreview(rate, hours)
        : null;
    final extras = widget.approvedAdjustmentsTotal;
    final homeownerPays = labour != null ? (labour + extras) : null;

    final commissionPercent = Decimal.tryParse(
      '${ref.watch(localeConfigProvider).valueOrNull?['commissionPercent'] ?? ''}',
    );
    final commission =
        (labour != null &&
            commissionPercent != null &&
            commissionPercent > Decimal.zero)
        ? ((labour * commissionPercent) / Decimal.fromInt(100)).toDecimal(
            scaleOnInfinitePrecision: 2,
          )
        : null;
    final youReceive = (homeownerPays != null && commission != null)
        ? (homeownerPays - commission)
        : null;

    return THScaffold(
      appBar: THAppBar(title: 'Complete job', subtitle: widget.job.title),
      stickyBar: THStickyBar(
        children: [
          THButton(
            key: const Key('check_out_submit_button'),
            label: 'Send for approval',
            kind: THButtonKind.accent,
            loading: _submitting,
            onPressed: (hours != null && !_submitting) ? _submit : null,
          ),
        ],
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          THCard(
            padding: Space.s4,
            children: [
              const THText(
                'FINAL HOURS',
                style: THTextStyle.label,
                tone: THTone.soft,
              ),
              const SizedBox(height: Space.s2_5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s3,
                children: [
                  THIconButton(
                    icon: Icons.remove_rounded,
                    kind: THButtonKind.secondary,
                    semanticLabel: 'minus',
                    onPressed: (hours == null || hours > _minHours)
                        ? () => _stepHours(-_step)
                        : null,
                  ),
                  Expanded(
                    child: TextField(
                      key: const Key('final_hours_field'),
                      controller: _hoursController,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        suffixText: 'h',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  THIconButton(
                    icon: Icons.add_rounded,
                    kind: THButtonKind.secondary,
                    semanticLabel: 'plus',
                    onPressed: (hours == null || hours < _maxHours)
                        ? () => _stepHours(_step)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          if (labour != null && homeownerPays != null)
            THCard(
              padding: Space.s4,
              children: [
                THKeyValue(
                  'Labour · ${trFormatHours(hours!)} h × ${formatMoney(rate!)}',
                  formatMoney(labour),
                  bold: true,
                ),
                if (extras > Decimal.zero)
                  THKeyValue(
                    'Approved extras',
                    formatMoney(extras),
                    bold: true,
                    divider: true,
                  ),
                THKeyValue(
                  'Homeowner pays',
                  formatMoney(homeownerPays),
                  bold: true,
                  strong: true,
                  divider: true,
                ),
              ],
            ),
          if (commission != null && youReceive != null)
            THCard(
              tone: THCardTone.accent,
              padding: Space.s4,
              children: [
                THKeyValue(
                  'Commission (${commissionPercent!}% on labour)',
                  '−${formatMoney(commission)}',
                  bold: true,
                ),
                THKeyValue(
                  'You receive',
                  formatMoney(youReceive),
                  bold: true,
                  strong: true,
                  divider: true,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
