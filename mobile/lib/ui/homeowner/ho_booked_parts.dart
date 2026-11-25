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

/// Initials for the avatar when no public profile loaded (never invented:
/// derived only from the name we already show).
String bookedInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts[1][0]).toUpperCase();
}

/// Matched-tradie card (mockup ho_job_booked): avatar, business name,
/// "rate incl. GST · locked" and a single chat icon button. The card opens the
/// tradie's public profile; chat is the only inline action.
class HoBookedTradieCard extends StatelessWidget {
  const HoBookedTradieCard({
    super.key,
    required this.name,
    required this.profile,
    required this.subtitle,
    required this.onViewProfile,
    required this.onChat,
  });
  final String name;
  final UserProfile? profile;
  final String? subtitle;
  final VoidCallback? onViewProfile;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) => THCard(
    children: [
      Row(
        spacing: Space.s3,
        children: [
          Expanded(
            child: Semantics(
              button: onViewProfile != null,
              label: onViewProfile != null ? 'View tradie profile' : null,
              child: InkWell(
                key: const Key('tradie_card_profile_button'),
                onTap: onViewProfile,
                borderRadius: BorderRadius.circular(Radii.control),
                child: Row(
                  spacing: Space.s3,
                  children: [
                    THAvatar(
                      profile?.initials.isNotEmpty == true
                          ? profile!.initials
                          : bookedInitials(name),
                      size: THAvatarSize.md,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          THText(name, style: THTextStyle.title),
                          if (subtitle != null)
                            THText(
                              subtitle!,
                              style: THTextStyle.meta,
                              tone: THTone.soft,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          THIconButton(
            key: const Key('tradie_card_chat_button'),
            icon: Icons.chat_bubble_rounded,
            kind: THButtonKind.secondary,
            semanticLabel: 'chat',
            onPressed: onChat,
          ),
        ],
      ),
    ],
  );
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
