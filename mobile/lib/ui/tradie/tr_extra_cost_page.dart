// TrExtraCostPage: Full-screen v2 request extra cost page (plan 5.4).
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

/// Launches the v2 full-screen extra-cost request page (D-P5-2) and returns
/// the `(kind, amount, description)` tuple expected by `JobsRepository.createAdjustment`.
Future<(String, Decimal, String)?> pushTrExtraCost(
  BuildContext context, {
  String? homeownerFirstName,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<(String, Decimal, String)?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TrExtraCostPage(homeownerFirstName: homeownerFirstName),
    ),
  );
}

class TrExtraCostPage extends ConsumerStatefulWidget {
  const TrExtraCostPage({super.key, this.homeownerFirstName});

  final String? homeownerFirstName;

  @override
  ConsumerState<TrExtraCostPage> createState() => _TrExtraCostPageState();
}

class _TrExtraCostPageState extends ConsumerState<TrExtraCostPage> {
  static const List<(String, String)> _kinds = <(String, String)>[
    (JobAdjustment.kindMaterials, 'Materials'),
    (JobAdjustment.kindExtraLabour, 'Extra work'),
    (JobAdjustment.kindTravel, 'Travel'),
    (JobAdjustment.kindOther, 'Other'),
  ];

  String _kind = JobAdjustment.kindMaterials;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Decimal? get _parsedAmount => Decimal.tryParse(_amountController.text.trim());

  bool get _canSubmit {
    if (_submitting) return false;
    final amount = _parsedAmount;
    final desc = _descriptionController.text.trim();
    return amount != null &&
        amount > Decimal.zero &&
        desc.isNotEmpty &&
        desc.length <= 500;
  }

  void _submit() {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    Navigator.of(context)
        .pop((_kind, _parsedAmount!, _descriptionController.text.trim()));
  }

  @override
  Widget build(BuildContext context) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: Builder(builder: (ctx) => _page(ctx)),
  );

  Widget _page(BuildContext context) {
    final name = widget.homeownerFirstName?.trim();
    final subtitle = (name != null && name.isNotEmpty)
        ? '$name must approve before billing'
        : 'The homeowner approves or declines before billing';

    return THScaffold(
      appBar: THAppBar(title: 'Request extra cost', subtitle: subtitle),
      stickyBar: THStickyBar(
        children: [
          THButton(
            key: const Key('extra_cost_submit_button'),
            label: 'Send request',
            kind: THButtonKind.accent,
            loading: _submitting,
            onPressed: _canSubmit ? _submit : null,
          ),
        ],
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          const THText('TYPE', style: THTextStyle.label, tone: THTone.soft),
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: _kinds
                .map(
                  (k) => ChoiceChip(
                    key: Key('extra_cost_kind_${k.$1}'),
                    label: Text(k.$2),
                    selected: _kind == k.$1,
                    onSelected: (_) => setState(() => _kind = k.$1),
                  ),
                )
                .toList(),
          ),
          TextField(
            key: const Key('extra_cost_amount_field'),
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'AMOUNT · INCL. GST',
              prefixText: '\$',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            key: const Key('extra_cost_description_field'),
            controller: _descriptionController,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'WHAT IS IT FOR?',
              hintText: 'e.g. Replacement tap cartridge',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          THCard(
            padding: Space.s3_5,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.s2_5,
                children: [
                  THIcon(
                    Icons.info_outline_rounded,
                    size: Sizes.iconSm,
                    tone: THTone.brand,
                  ),
                  const Expanded(
                    child: THText(
                      'Requests expire after 24 hours. Commission applies to labour only.',
                      style: THTextStyle.meta,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
