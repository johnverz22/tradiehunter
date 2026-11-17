import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import '../../models/marketplace.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

const bookedCancellationNotice =
    'Cancelling a booked job incurs a 10% platform fee.';

String bookedTimingLabel(String? preference) => switch (preference) {
  'Flexible' => 'Flexible',
  'Asap' => 'As soon as possible',
  'SpecificDate' || 'DateRange' => 'Date to be confirmed',
  _ => 'Date to be confirmed',
};

String bookedDurationLabel(Job job) {
  if (job.hours > 0) {
    return '${job.hours} ${job.hours == 1 ? 'hour' : 'hours'}';
  }
  if (job.estimatedHours case final hours?) {
    final amount = hours == hours.roundToDouble()
        ? hours.toInt().toString()
        : hours.toString();
    return '≈ $amount ${hours == 1 ? 'hour' : 'hours'}';
  }
  return 'To be confirmed';
}

Decimal? bookedEstimate(Job job) =>
    job.estimatedTotal ??
    (job.flowVersion < Job.flowVersionV2 ? job.totalAmount : null);

String bookedTradieName(Job job, UserProfile? profile) {
  final business = profile?.businessName?.trim();
  if (business?.isNotEmpty == true) return business!;
  if (profile?.fullName.isNotEmpty == true) return profile!.fullName;
  return job.matchedTradieName ?? '';
}

class HoBookedTradieCard extends StatelessWidget {
  const HoBookedTradieCard({
    super.key,
    required this.name,
    required this.profile,
    required this.canViewProfile,
    required this.onViewProfile,
    required this.onChat,
    required this.onCall,
  });
  final String name;
  final UserProfile? profile;
  final bool canViewProfile;
  final VoidCallback? onViewProfile;
  final VoidCallback onChat;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) => THCard(
    children: [
      Row(
        spacing: Space.s3,
        children: [
          if (profile != null) THAvatar(profile!.initials),
          Expanded(child: THText(name, style: THTextStyle.title)),
          if (canViewProfile)
            IconButton(
              tooltip: 'View tradie profile',
              onPressed: onViewProfile,
              icon: const Icon(Icons.open_in_new),
            ),
        ],
      ),
      if (profile?.isVerified == true || profile?.hasInsurance == true) ...[
        const SizedBox(height: Space.s2),
        Wrap(
          spacing: Space.s2,
          children: [
            if (profile?.isVerified == true)
              const THBadge('Verified', kind: THBadgeKind.ok),
            if (profile?.hasInsurance == true)
              const THBadge('Insured', kind: THBadgeKind.ok),
          ],
        ),
      ],
      const SizedBox(height: Space.s2),
      Row(
        spacing: Space.s2,
        children: [
          Expanded(
            child: THButton(
              key: const Key('tradie_card_chat_button'),
              label: 'Message',
              icon: Icons.chat_bubble_outline,
              kind: THButtonKind.secondary,
              onPressed: onChat,
            ),
          ),
          if (onCall != null)
            Expanded(
              child: THButton(
                key: const Key('tradie_card_call_button'),
                label: 'Call',
                icon: Icons.phone_outlined,
                kind: THButtonKind.secondary,
                onPressed: onCall,
              ),
            ),
        ],
      ),
    ],
  );
}

class HoJobTimelineRow extends StatelessWidget {
  const HoJobTimelineRow(
    this.label, {
    super.key,
    this.done = false,
    this.current = false,
  });
  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = done || current ? context.th.textBrand : context.th.textSoft;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s1),
      child: Row(
        spacing: Space.s2,
        children: [
          Icon(
            done
                ? Icons.check_circle
                : current
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: Sizes.iconSm,
            color: color,
          ),
          Expanded(
            child: THText(
              label,
              style: THTextStyle.body,
              tone: done || current ? THTone.base : THTone.soft,
            ),
          ),
        ],
      ),
    );
  }
}

class HoCancelJobSheet extends StatefulWidget {
  const HoCancelJobSheet({super.key});

  @override
  State<HoCancelJobSheet> createState() => _HoCancelJobSheetState();
}

class _HoCancelJobSheetState extends State<HoCancelJobSheet> {
  static const _reasons = [
    ('homeowner_changed_mind', 'Changed my mind'),
    ('emergency', 'Emergency situation'),
    ('scope_change_declined', 'Scope changed — tradie declined'),
    ('homeowner_issue', 'Personal / scheduling issue'),
  ];
  String? _reason;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(Space.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: Space.s2,
            children: [
              const THText('Cancel this job', style: THTextStyle.title),
              const THCard(
                tone: THCardTone.danger,
                children: [
                  THText(bookedCancellationNotice, style: THTextStyle.body),
                ],
              ),
              const THText('Reason', style: THTextStyle.label),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (value) => setState(() => _reason = value),
                child: Column(
                  children: [
                    for (final (code, label) in _reasons)
                      RadioListTile<String>(
                        value: code,
                        title: THText(label, style: THTextStyle.body),
                      ),
                  ],
                ),
              ),
              const THText(
                'Additional notes (optional)',
                style: THTextStyle.label,
              ),
              THTextField(controller: _notes, maxLines: 3),
              THButton(
                key: const Key('cancel_confirm_button'),
                label: 'Confirm cancellation',
                kind: THButtonKind.danger,
                onPressed: _reason == null
                    ? null
                    : () => Navigator.pop(context, (
                        reason: _reason!,
                        notes: _notes.text.trim().isEmpty
                            ? null
                            : _notes.text.trim(),
                      )),
              ),
              THButton(
                key: const Key('cancel_dismiss_button'),
                label: 'Keep job',
                kind: THButtonKind.ghost,
                onPressed: () => Navigator.pop(context, null),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
