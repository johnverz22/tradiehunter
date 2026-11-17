import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../../utils/money.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoTradieSummary extends StatelessWidget {
  const HoTradieSummary({super.key, required this.name, required this.profile});

  final String name;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) => THCard(
    children: [
      Row(
        spacing: Space.s3,
        children: [
          if (profile != null) THAvatar(profile!.initials),
          Expanded(child: THText(name, style: THTextStyle.title)),
        ],
      ),
      if (profile?.isVerified == true || profile?.hasInsurance == true) ...[
        const SizedBox(height: Space.s2),
        Wrap(
          spacing: Space.s2,
          runSpacing: Space.s2,
          children: [
            if (profile?.isVerified == true)
              const THBadge('Verified', kind: THBadgeKind.ok),
            if (profile?.hasInsurance == true)
              const THBadge('Insured', kind: THBadgeKind.ok),
          ],
        ),
      ],
    ],
  );
}

class HoPendingAdjustmentCard extends StatelessWidget {
  const HoPendingAdjustmentCard({
    super.key,
    required this.adjustment,
    required this.busy,
    required this.onApprove,
    required this.onDecline,
  });

  final JobAdjustment adjustment;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => THCard(
    tone: THCardTone.accent,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: Space.s2,
        children: [
          const Expanded(
            child: THBadge('Extra cost request', kind: THBadgeKind.accent),
          ),
          if (adjustment.expiresAtUtc != null)
            THText(
              'Expires ${MaterialLocalizations.of(context).formatShortDate(adjustment.expiresAtUtc!.toLocal())}',
              style: THTextStyle.meta,
              tone: THTone.soft,
            ),
        ],
      ),
      const SizedBox(height: Space.s3),
      THText(formatMoney(adjustment.amount), style: THTextStyle.moneyLg),
      THText(
        'Incl. GST · ${adjustment.kind}',
        style: THTextStyle.meta,
        tone: THTone.soft,
      ),
      const SizedBox(height: Space.s2),
      THText(
        adjustment.description.isEmpty
            ? 'No description provided.'
            : adjustment.description,
        style: THTextStyle.body,
      ),
      if (adjustment.evidenceUrl?.isNotEmpty == true) ...[
        const SizedBox(height: Space.s2),
        THText('A receipt or photo is attached.', style: THTextStyle.meta),
      ],
      const SizedBox(height: Space.s3),
      Row(
        spacing: Space.s2,
        children: [
          Expanded(
            child: THButton(
              label: 'Decline',
              kind: THButtonKind.secondary,
              size: THButtonSize.sm,
              onPressed: busy ? null : onDecline,
            ),
          ),
          Expanded(
            child: THButton(
              label: busy ? 'Saving…' : 'Approve',
              kind: THButtonKind.primary,
              size: THButtonSize.sm,
              onPressed: busy ? null : onApprove,
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.s2),
      const THText(
        'Nothing is billed until you approve it. Approved extras are recorded against the job.',
        style: THTextStyle.meta,
        tone: THTone.soft,
      ),
    ],
  );
}

class HoAdjustmentDecisionSheet extends StatefulWidget {
  const HoAdjustmentDecisionSheet({
    super.key,
    required this.adjustment,
    required this.approve,
    required this.estimate,
  });

  final JobAdjustment adjustment;
  final bool approve;
  final Decimal? estimate;

  @override
  State<HoAdjustmentDecisionSheet> createState() =>
      _HoAdjustmentDecisionSheetState();
}

class _HoAdjustmentDecisionSheetState extends State<HoAdjustmentDecisionSheet> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.adjustment;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Sizes.gutter,
          Space.s5,
          Sizes.gutter,
          MediaQuery.viewInsetsOf(context).bottom + Space.s5,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.s3,
            children: [
              THText('Extra cost request', style: THTextStyle.h2),
              THText(
                a.description.isEmpty ? a.kind : a.description,
                style: THTextStyle.body,
              ),
              THKeyValue('Amount · incl. GST', formatMoney(a.amount)),
              if (a.evidenceUrl?.isNotEmpty == true)
                const THText(
                  'A receipt or photo is attached.',
                  style: THTextStyle.meta,
                  tone: THTone.soft,
                ),
              if (widget.estimate != null)
                THKeyValue(
                  'Estimate before this request',
                  formatMoney(widget.estimate!),
                ),
              TextField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              THButton(
                label: widget.approve
                    ? 'Approve this extra cost'
                    : 'Decline this extra cost',
                kind: widget.approve
                    ? THButtonKind.primary
                    : THButtonKind.secondary,
                onPressed: () =>
                    Navigator.pop(context, _noteController.text.trim()),
              ),
              THText(
                widget.approve
                    ? 'This approval adds the request to the job total. You’ll review the final amount before payment.'
                    : 'A declined extra is not added to the job total.',
                style: THTextStyle.meta,
                tone: THTone.soft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
