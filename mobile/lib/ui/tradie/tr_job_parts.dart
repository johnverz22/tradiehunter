// Shared components for the v2 tradie job detail (plan 5.3).
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../network/external_launcher.dart';
import '../../utils/money.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import 'tr_job_state.dart';

/// Top app bar with back navigation and the overflow menu.
class TrJobAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TrJobAppBar({
    super.key,
    required this.job,
    required this.busy,
    required this.onCancel,
    required this.onReportNoShow,
    required this.onDispute,
  });

  final Job job;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onReportNoShow;
  final VoidCallback onDispute;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final status = job.status;
    final canCancel = trCanCancel(status);
    final canDispute = trCanDispute(status);
    final canReportNoShow = trCanReportNoShow(job);

    final showOverflow = (canCancel && !busy) || canDispute || canReportNoShow;

    return THAppBar(
      title: job.title,
      subtitle: job.category,
      actions: [
        if (showOverflow)
          Semantics(
            identifier: 'job_overflow_menu',
            child: PopupMenuButton<String>(
              key: const Key('job_overflow_menu'),
              icon: Icon(Icons.more_vert_rounded, color: context.th.text),
              onSelected: (value) {
                switch (value) {
                  case 'noshow':
                    onReportNoShow();
                  case 'dispute':
                    onDispute();
                  case 'cancel':
                    onCancel();
                }
              },
              itemBuilder: (context) => [
                if (canReportNoShow)
                  const PopupMenuItem(
                    value: 'noshow',
                    child: Text('Report No-Show'),
                  ),
                if (canDispute)
                  const PopupMenuItem(
                    value: 'dispute',
                    child: Text('Open Dispute'),
                  ),
                if (canCancel && !busy)
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text(
                      'Cancel Job',
                      style: TextStyle(color: context.th.danger),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Job reference code chip. Long-pressing copies to clipboard with a notice.
class TrJobCodeBadge extends StatelessWidget {
  const TrJobCodeBadge({super.key, required this.referenceCode});
  final String referenceCode;

  @override
  Widget build(BuildContext context) {
    if (referenceCode.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: 'Long-press to copy job code',
      child: GestureDetector(
        key: const Key('status_strip_job_code'),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: referenceCode));
          THNotice.info(context, 'Job code copied: $referenceCode');
        },
        child: Text(
          referenceCode,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.0,
            fontWeight: FW.medium,
            color: context.th.textSoft,
          ),
        ),
      ),
    );
  }
}

/// Homeowner contact card.
class TrContactCard extends StatelessWidget {
  const TrContactCard({
    super.key,
    required this.contact,
    required this.address,
    required this.onMessage,
    required this.onCall,
  });

  final JobContact contact;
  final String address;
  final VoidCallback onMessage;
  final ValueChanged<String> onCall;

  @override
  Widget build(BuildContext context) {
    final phone = contact.phoneNumber?.trim();
    final canCall = phone != null && phone.isNotEmpty;
    final name = contact.firstName.isNotEmpty ? contact.firstName : 'Homeowner';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'H';

    return THCard(
      padding: Space.s3_5,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: Space.s3,
          children: [
            THAvatar(initial, size: THAvatarSize.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 2.0,
                children: [
                  THText(name, style: THTextStyle.title),
                  THText(address, style: THTextStyle.meta, tone: THTone.soft),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.s3),
        Row(
          spacing: Space.s2,
          children: [
            Expanded(
              child: THButton(
                key: const Key('message_homeowner_button'),
                label: 'Message',
                icon: Icons.chat_bubble_outline_rounded,
                kind: THButtonKind.secondary,
                onPressed: onMessage,
              ),
            ),
            if (canCall)
              Expanded(
                child: THButton(
                  key: const Key('call_homeowner_button'),
                  label: 'Call',
                  icon: Icons.phone_outlined,
                  kind: THButtonKind.secondary,
                  onPressed: () => onCall(phone),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Location row with optional navigate button.
class TrLocationCard extends StatelessWidget {
  const TrLocationCard({
    super.key,
    required this.job,
    required this.onNavigate,
  });

  final Job job;
  final ValueChanged<MapApp?> onNavigate;

  void _showMapPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ThScope(
        themeMode: ThemeMode.system,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('Apple Maps'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onNavigate(MapApp.appleMaps);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.navigation_outlined),
                  title: const Text('Google Maps'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onNavigate(MapApp.googleMaps);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFull = trIsBookedOrLater(job.status);
    final address = trAddressLabel(job);
    final canNavigate =
        showFull &&
        ((job.address?.isNotEmpty ?? false) ||
            (job.latitude != null && job.longitude != null));

    return THCard(
      padding: Space.s4,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              showFull ? Icons.location_on_rounded : Icons.location_on_outlined,
              size: Sizes.iconLg,
              color: context.th.brand,
            ),
            const SizedBox(width: Space.s2_5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  THText(
                    showFull ? 'Full address' : 'Approximate location',
                    style: THTextStyle.meta,
                    tone: THTone.soft,
                  ),
                  const SizedBox(height: 2.0),
                  THText(address, style: THTextStyle.body),
                  if (!showFull) ...[
                    const SizedBox(height: Space.s1),
                    THText(
                      'Full address shown once booked.',
                      style: THTextStyle.meta,
                      tone: THTone.soft,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (canNavigate) ...[
          const SizedBox(height: Space.s3),
          THButton(
            key: const Key('navigate_button'),
            label: 'Navigate',
            icon: Icons.directions_outlined,
            kind: THButtonKind.secondary,
            onPressed: () => _showMapPicker(context),
          ),
        ],
      ],
    );
  }
}

/// Job details: service, rate, duration, net earnings and description.
class TrJobDetailsCard extends StatelessWidget {
  const TrJobDetailsCard({
    super.key,
    required this.job,
    required this.commissionPercent,
  });

  final Job job;
  final Decimal? commissionPercent;

  @override
  Widget build(BuildContext context) {
    final scheduledLabel = job.scheduledStartUtc != null
        ? DateFormat.MMMEd().add_jm().format(job.scheduledStartUtc!.toLocal())
        : null;

    final durationLabel = job.hours > 0
        ? '${job.hours} ${job.hours != 1 ? 'hours' : 'hour'}'
        : (job.estimatedHours != null
              ? '≈ ${trFormatHours(job.estimatedHours!)} hours'
              : 'TBC');

    final total = job.finalAmount ?? job.estimatedTotal ?? job.totalAmount;
    final totalLabel = job.finalAmount != null
        ? 'Job total'
        : (job.estimatedTotal != null ? 'Estimated total' : 'Job total');
    final grossLabel = total != null ? formatMoney(total) : null;
    final net = payoutNetAmount(total, commissionPercent);

    return THCard(
      padding: Space.s4,
      children: [
        THKeyValue('Service', job.category),
        if (job.hourlyRate != null)
          THKeyValue(
            'Rate',
            '${formatMoney(job.hourlyRate!)}/hr incl. GST',
            divider: true,
          ),
        THKeyValue('Scheduled', scheduledLabel ?? 'Date TBC', divider: true),
        THKeyValue('Duration', durationLabel, divider: true),
        if (grossLabel != null) ...[
          if (net != null && commissionPercent != null) ...[
            THKeyValue('You earn', formatMoney(net), divider: true),
            THKeyValue(totalLabel, grossLabel, divider: true),
          ] else ...[
            THKeyValue('You earn', grossLabel, divider: true),
          ],
        ],
        if (job.description?.isNotEmpty == true) ...[
          const SizedBox(height: Space.s3),
          THText('Job Description', style: THTextStyle.title),
          const SizedBox(height: Space.s1),
          THText(job.description!, style: THTextStyle.body),
        ],
      ],
    );
  }
}

/// Extra costs card showing pending and approved adjustments.
class TrAdjustmentsCard extends StatelessWidget {
  const TrAdjustmentsCard({
    super.key,
    required this.adjustments,
    required this.onRequestExtra,
    required this.onWithdraw,
  });

  final List<JobAdjustment> adjustments;
  final VoidCallback onRequestExtra;
  final ValueChanged<JobAdjustment> onWithdraw;

  @override
  Widget build(BuildContext context) {
    final approvedTotal = trApprovedAdjustmentsTotal(adjustments);

    return THCard(
      padding: Space.s4,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: THText('Extra costs', style: THTextStyle.title),
            ),
            if (approvedTotal > Decimal.zero)
              THBadge(
                'Approved: ${formatMoney(approvedTotal)}',
                kind: THBadgeKind.ok,
              ),
          ],
        ),
        const SizedBox(height: Space.s1),
        THText(
          'Ask the homeowner to approve extra costs — materials, labour, travel. '
          'Nothing is billed without their approval.',
          style: THTextStyle.meta,
          tone: THTone.soft,
        ),
        const SizedBox(height: Space.s3),
        THButton(
          key: const Key('request_extra_cost_button'),
          label: 'Request extra cost',
          icon: Icons.add_circle_outline_rounded,
          kind: THButtonKind.secondary,
          onPressed: onRequestExtra,
        ),
        if (adjustments.isNotEmpty) ...[
          const SizedBox(height: Space.s3),
          for (final a in adjustments) ...[
            _AdjustmentRow(
              adjustment: a,
              onWithdraw: a.isPending ? () => onWithdraw(a) : null,
            ),
            const SizedBox(height: Space.s2),
          ],
        ],
      ],
    );
  }
}

class _AdjustmentRow extends StatelessWidget {
  const _AdjustmentRow({required this.adjustment, this.onWithdraw});
  final JobAdjustment adjustment;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final a = adjustment;
    final (kind, label) = switch (a.status) {
      JobAdjustment.statusApproved => (THBadgeKind.ok, 'Approved'),
      JobAdjustment.statusDeclined => (THBadgeKind.danger, 'Declined'),
      JobAdjustment.statusPending => (
        THBadgeKind.accent,
        'Waiting for approval',
      ),
      JobAdjustment.statusWithdrawn => (THBadgeKind.glass, 'Withdrawn'),
      JobAdjustment.statusExpired => (THBadgeKind.glass, 'Expired'),
      _ => (THBadgeKind.glass, a.status),
    };

    return Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(
        color: context.th.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: context.th.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: THBadge(label, kind: kind)),
              Flexible(
                child: THText(
                  formatMoney(a.amount),
                  style: THTextStyle.title,
                  align: TextAlign.right,
                ),
              ),
            ],
          ),
          if (a.description.isNotEmpty) ...[
            const SizedBox(height: Space.s1),
            THText(a.description, style: THTextStyle.body),
          ],
          const SizedBox(height: Space.s1),
          THText(
            [
              a.kind,
              'sent ${DateFormat('d MMM').format(a.createdAtUtc.toLocal())}',
              if (a.evidenceUrl?.isNotEmpty == true) 'receipt attached',
            ].join(' · '),
            style: THTextStyle.meta,
            tone: THTone.soft,
          ),
          if (onWithdraw != null) ...[
            const SizedBox(height: Space.s2),
            Align(
              alignment: Alignment.centerRight,
              child: THButton(
                key: Key('adjustment_withdraw_${a.id}'),
                label: 'Withdraw',
                kind: THButtonKind.secondary,
                onPressed: onWithdraw,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tradie cancellation bottom sheet.
class TrCancelJobSheet extends StatefulWidget {
  const TrCancelJobSheet({super.key});

  @override
  State<TrCancelJobSheet> createState() => _TrCancelJobSheetState();
}

class _TrCancelJobSheetState extends State<TrCancelJobSheet> {
  String? _selectedReason = trTradieCancelReasons.first.$1;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThScope(
      themeMode: ThemeMode.system,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Space.s5,
            Space.s4,
            Space.s5,
            MediaQuery.of(context).viewInsets.bottom + Space.s4,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const THText('Cancel Job', style: THTextStyle.h2),
                const SizedBox(height: Space.s1),
                const THText(
                  'Please select a reason for cancelling this job.',
                  style: THTextStyle.meta,
                  tone: THTone.soft,
                ),
                const SizedBox(height: Space.s4),
                RadioGroup<String>(
                  groupValue: _selectedReason,
                  onChanged: (val) => setState(() => _selectedReason = val),
                  child: Column(
                    children: [
                      for (final (code, label) in trTradieCancelReasons)
                        RadioListTile<String>(
                          title: Text(label),
                          value: code,
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.s3),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Additional notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: Space.s4),
                Row(
                  spacing: Space.s2,
                  children: [
                    Expanded(
                      child: THButton(
                        key: const Key('cancel_dismiss_button'),
                        label: 'Keep job',
                        kind: THButtonKind.secondary,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Expanded(
                      child: THButton(
                        key: const Key('cancel_confirm_button'),
                        label: 'Cancel job',
                        kind: THButtonKind.danger,
                        onPressed: _selectedReason == null
                            ? null
                            : () => Navigator.pop(context, (
                                reasonCode: _selectedReason!,
                                notes: _notesController.text.trim().isEmpty
                                    ? null
                                    : _notesController.text.trim(),
                              )),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirmation dialog for reporting a homeowner no-show.
Future<bool?> showTrReportNoShowDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Report Homeowner No-Show'),
      content: const Text(
        'Are you sure the homeowner is not present? This will cancel the job and apply a penalty to the homeowner.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Report No-Show',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    ),
  );
}

/// Dialog presenting the server-returned check-out summary.
void showTrCheckOutSummaryDialog(
  BuildContext context,
  CheckOutSummary summary,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Check-out submitted'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (summary.finalHours != null)
              Text('Hours worked: ${trFormatHours(summary.finalHours!)}'),
            if (summary.labourAmount != null)
              Text('Labour: ${formatMoney(summary.labourAmount!)}'),
            if (summary.adjustmentsTotal != null &&
                summary.adjustmentsTotal! > Decimal.zero)
              Text(
                'Approved extras: ${formatMoney(summary.adjustmentsTotal!)}',
              ),
            if (summary.finalAmount != null)
              Text('Final total: ${formatMoney(summary.finalAmount!)}'),
            if (summary.estimatedTotal != null && summary.finalAmount != null)
              Text(
                'Original estimate: ${formatMoney(summary.estimatedTotal!)}',
              ),
            const SizedBox(height: Space.s2),
            Text(
              summary.exceedsTolerance
                  ? (summary.toleranceNote?.isNotEmpty == true
                        ? summary.toleranceNote!
                        : 'This total is above the estimate tolerance — the '
                              'homeowner will review it before paying.')
                  : 'The homeowner now reviews the summary and approves the amount.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
