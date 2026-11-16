import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/marketplace.dart' show Job;
import '../../models/payment.dart';
import '../../theme/design_tokens.dart';
import '../../utils/money.dart';
import '../../viewmodels/locale_viewmodel.dart';
import '../../viewmodels/payment_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../widgets/fixo_feedback.dart';
import '../widgets/fixo_rows.dart';
import '../widgets/sticky_action_bar.dart';
import '../../feedback/fixo_notice.dart';

/// Homeowner payment screen (P4-07).
///
/// v1.7: this screen is entered from "Approve & pay" on the itemised review
/// — the homeowner has already approved the completed work, and paying here
/// settles it (it is never a booking deposit).
///
/// Shows the transfer instructions — amount, itemised breakdown, bank
/// details, and the job-specific reference that has to be quoted — plus a
/// receipt picker. The money moves out of band; this screen's whole job is
/// making the reference unambiguous and getting the resulting receipt in
/// front of staff.
class PaymentScreen extends ConsumerStatefulWidget {
  final String jobId;
  const PaymentScreen({super.key, required this.jobId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(paymentViewModelProvider(widget.jobId).notifier).load(),
    );
  }

  Future<void> _pickAndUpload() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      // Keep it to something a bank app would produce; the server caps at 10 MB.
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    final ok = await ref
        .read(paymentViewModelProvider(widget.jobId).notifier)
        .uploadReceipt(picked.path);
    if (!mounted) return;

    if (ok) {
      _toast('Receipt sent for review.');
      await context.push('/jobs/${widget.jobId}/payment/status');
    }
  }

  void _toast(String message) {
    FixoNotice.errorDynamic(context, message);
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _toast('$label copied.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(paymentViewModelProvider(widget.jobId));
    final payment = state.payment;

    return Scaffold(
      key: const Key('payment_screen'),
      appBar: FixoAppBar(
        title: 'Payment',
        subtitle: payment?.jobTitle,
        actions: [
          FixoAppBarAction(
            icon: Icons.receipt_long_outlined,
            tooltip: 'Payment status',
            onTap: () => context.push('/jobs/${widget.jobId}/payment/status'),
          ),
        ],
      ),
      body: _body(context, theme, isDark, state, payment),
      bottomNavigationBar: (payment != null && payment.canUploadReceipt)
          ? StickyActionBar(child: _actionBar(state, payment))
          : null,
    );
  }

  /// State B (details usable): upload is the primary action. State A (details
  /// missing or sentinel): uploading is withheld — a receipt for a transfer
  /// the homeowner was told not to make is meaningless — so refreshing the
  /// details becomes the primary action instead.
  Widget _actionBar(PaymentState state, PaymentStatus payment) {
    final bankReady = payment.bankDetails?.isAvailable ?? false;
    if (bankReady) {
      return FixoPrimaryButton(
        key: const Key('upload_receipt_button'),
        label: state.isUploading ? 'Uploading…' : 'Upload bank receipt',
        isLoading: state.isUploading,
        onPressed: _pickAndUpload,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Upload is available once bank details are shown.',
          key: const Key('upload_disabled_hint'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Space.s2),
        FixoPrimaryButton(
          key: const Key('refresh_payment_button'),
          label: state.isLoading ? 'Refreshing…' : 'Refresh payment details',
          isLoading: state.isLoading,
          onPressed: () =>
              ref.read(paymentViewModelProvider(widget.jobId).notifier).load(),
        ),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    PaymentState state,
    PaymentStatus? payment,
  ) {
    if (state.isLoading && payment == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (payment == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.s6,
          Space.s6,
          Space.s6,
          Space.s6,
        ),
        children: [
          if (state.error != null)
            FixoInfoBanner.error(
              message: state.error!,
              action: TextButton(
                onPressed: () => ref
                    .read(paymentViewModelProvider(widget.jobId).notifier)
                    .load(),
                child: const Text('Retry'),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    // P10-22: materials disclaimer from locale config
    final localeAsync = ref.watch(localeConfigProvider);
    final materialsDisclaimer =
        localeAsync.value?['materialsDisclaimer'] as String?;

    // The hours × rate breakdown comes from the job, not the payment — a
    // missing or failed job read drops the line rather than inventing a rate.
    final job = ref.watch(paymentJobProvider(widget.jobId)).valueOrNull;
    final bank = payment.bankDetails;
    final bankReady = bank?.isAvailable ?? false;

    return ListView(
      padding: FixoPadding.page,
      children: [
        StatusBadge(
          label: payment.stage.label,
          kind: _badgeKind(payment.stage),
        ),

        if (state.error != null) ...[
          const SizedBox(height: Space.s4),
          FixoInfoBanner.error(message: state.error!),
        ],

        // ── H14 navy gradient amount card ────────────────────────────────
        const SizedBox(height: Space.s4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Space.s5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [DesignTokens.brand900, DesignTokens.brand700],
            ),
            borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Amount to pay',
                style: TextStyle(
                  fontFamily: DesignTokens.fontBody,
                  fontSize: DesignTokens.fontSizeSecondary,
                  color: Colors.white.withValues(alpha: Alpha.textOnGradient),
                ),
              ),
              const SizedBox(height: Space.s1),
              Text(
                formatMoney(payment.amount),
                style: const TextStyle(
                  fontFamily: DesignTokens.fontDisplay,
                  fontSize: DesignTokens.fontSizeAmountLg,
                  fontWeight: FW.extrabold,
                  color: Colors.white,
                ),
              ),
              if (job != null) ...[
                const SizedBox(height: Space.s1),
                Text(
                  // H14: "Leaking kitchen tap · Mike Te Rangi" — job and
                  // tradie on one caption line, middle-dot separated.
                  job.matchedTradieName?.trim().isNotEmpty == true
                      ? '${job.title} · ${job.matchedTradieName!.trim()}'
                      : job.title,
                  key: const Key('payment_amount_subtitle'),
                  style: TextStyle(
                    fontFamily: DesignTokens.fontBody,
                    fontSize: DesignTokens.fontSizeSecondary,
                    color: Colors.white.withValues(alpha: Alpha.textOnGradient),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── The breakdown ──────────────────────────────────────────────
        // v1.7: the payment settles the completed work, so the breakdown is
        // the server's own itemisation — labour + approved adjustments =
        // total (contract #7/#9). The legacy hours × rate line only shows
        // when the job predates itemisation; a missing figure is dropped,
        // never invented.
        const SizedBox(height: Space.s4),
        Builder(
          builder: (context) {
            final hasLabourRow = job != null && job.labourAmount != null;
            final hasLegacyLabourRow =
                job != null && job.hours > 0 && job.hourlyRate != null;
            final hasExtrasRow = job != null &&
                job.adjustmentsTotal != null &&
                job.adjustmentsTotal! > Decimal.zero;
            return FixoCard(
              child: Column(
                children: [
                  if (hasLabourRow)
                    FixoSummaryRow(
                      label: 'Labour',
                      value: formatMoney(job!.labourAmount!),
                    )
                  else if (hasLegacyLabourRow)
                    FixoSummaryRow(
                      label: 'Labour',
                      value:
                          '${job!.hours} h × ${formatRate(job.hourlyRate!)}',
                    ),
                  if (hasLabourRow || hasLegacyLabourRow)
                    const FixoListDivider(),
                  if (hasExtrasRow) ...[
                    FixoSummaryRow(
                      label: 'Approved extras',
                      value: formatMoney(job!.adjustmentsTotal!),
                    ),
                    const FixoListDivider(),
                  ],
                  FixoSummaryRow(
                    label: 'Job total',
                    value: formatMoney(payment.amount),
                    emphasize: true,
                  ),
                  const FixoListDivider(),
                  FixoSummaryRow(
                    label: 'Method',
                    value: _method(payment.method),
                  ),
                ],
              ),
            );
          },
        ),

        // ── P10-22: Materials disclaimer ────────────────────────────────
        if (materialsDisclaimer != null && materialsDisclaimer.isNotEmpty) ...[
          const SizedBox(height: Space.s3),
          FixoInfoBanner(
            icon: Icons.info_outline,
            message: materialsDisclaimer,
            tone: FixoTone.brand,
            compact: true,
          ),
        ],

        // ── Numbered transfer instructions ──────────────────────────────
        // Only rendered when the configured bank details are real. Missing or
        // sentinel details block the guidance — paying to a guessed account
        // is worse than paying late.
        if (bankReady) ...[
          const SizedBox(height: Space.s5),
          FixoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // H14 order: 1 Transfer to the tradie → 2 the reference →
                // 3 upload the receipt. The account move is the action the
                // homeowner performs first; the reference rides along with it.
                FixoStepRow(
                  number: 1,
                  title: 'Transfer to ${_tradieShort(job)}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FixoDetailRow(
                        label: 'Account name',
                        value: bank!.accountName,
                      ),
                      const SizedBox(height: Space.s2),
                      FixoDetailRow(
                        label: 'Account number',
                        value: bank.accountNumber,
                        mono: true,
                        onCopy: () =>
                            _copy(bank.accountNumber, 'Account number'),
                      ),
                      const SizedBox(height: Space.s2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('copy_all_button'),
                          icon: const Icon(Icons.copy_all_outlined),
                          label: const Text('Copy all'),
                          onPressed: () => _copy(
                            'Account name: ${bank.accountName}\n'
                                'Account number: ${bank.accountNumber}\n'
                                'Amount: ${formatMoney(payment.amount)}\n'
                                'Reference: ${payment.reference}',
                            'Payment details',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const FixoListDivider(spacing: 29),
                FixoStepRow(
                  number: 2,
                  title: 'Use this reference',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              payment.reference,
                              style: const TextStyle(
                                fontFamily: DesignTokens.fontMono,
                                fontSize: DesignTokens.fontSizeAmountSm,
                                fontWeight: FW.semibold,
                              ),
                            ),
                          ),
                          FixoCopyButton(
                            key: const Key('copy_reference_button'),
                            label: 'reference',
                            onTap: () => _copy(payment.reference, 'Reference'),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.s1),
                      Text(
                        'Quote this exact reference and amount so our team can match your transfer.',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeCaption,
                          color: DesignTokens.inkSoft(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const FixoListDivider(spacing: 29),
                FixoStepRow(
                  number: 3,
                  title: 'Upload your receipt',
                  child: Text(
                    'We check it within 1 business day.',
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeSecondary,
                      height: 1.45,
                      color: DesignTokens.inkSoft(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: Space.s5),
          FixoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: DesignTokens.amber,
                    ),
                    const SizedBox(width: Space.s2_5),
                    Expanded(
                      child: Text(
                        'Bank transfer details are unavailable. Do not transfer '
                        'money until valid instructions are available. Try '
                        'refreshing payment details.',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeSecondary,
                          height: 1.45,
                          color: DesignTokens.inkSoft(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!payment.canUploadReceipt) ...[
                  const SizedBox(height: Space.s3),
                  FixoGhostButton(
                    label: 'Refresh payment details',
                    onPressed: () => ref
                        .read(paymentViewModelProvider(widget.jobId).notifier)
                        .load(),
                  ),
                ],
              ],
            ),
          ),
        ],

        // ── Rejection: the reason and a route back to a new upload ───────
        if (payment.stage == PaymentStage.rejected) ...[
          const SizedBox(height: Space.s3),
          FixoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: DesignTokens.inkDanger(isDark),
                    ),
                    const SizedBox(width: Space.s2),
                    Text(
                      'What went wrong',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeSm,
                        fontWeight: FW.semibold,
                        color: DesignTokens.inkDanger(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.s2),
                Text(
                  payment.rejectReason ?? 'The receipt could not be accepted.',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSm,
                    height: 1.4,
                    color: DesignTokens.inkSoft(isDark),
                  ),
                ),
                if (payment.reUploadCount > 0) ...[
                  const SizedBox(height: Space.s2),
                  Text(
                    'Sent back ${payment.reUploadCount} '
                    '${payment.reUploadCount == 1 ? 'time' : 'times'}.',
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeCaption,
                      color: DesignTokens.inkSoft(isDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // ── H14 footer: deadline + what this payment is ───────────
        if (bankReady && payment.canUploadReceipt) ...[
          const SizedBox(height: Space.s3),
          Text(
            // v1.7: paying settles the completed work — never a booking
            // deposit or a match window.
            'Pay within ${payment.dueAtUtc.difference(DateTime.now()).inHours < 0 ? 0 : _windowHours(payment)} h. '
                'Your money goes straight to the tradie — this payment '
                'settles the completed work.',
            key: const Key('payment_window_note'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: DesignTokens.fontBody,
              fontSize: DesignTokens.fontSizeCaption,
              height: 1.45,
              color: DesignTokens.inkSoft(isDark),
            ),
          ),
        ],

        const SizedBox(height: Space.s5),
      ],
    );
  }

  /// Hours left on the server-set payment window, floor at 1 so the copy
  /// never reads "0 h" while the deadline is still ahead.
  static int _windowHours(PaymentStatus payment) {
    final left = payment.dueAtUtc.difference(DateTime.now()).inHours;
    return left < 1 ? 1 : left;
  }

  /// H14 step 1 title: the tradie's first name ("Transfer to Mike") when
  /// the job carries one; "the tradie" otherwise.
  static String _tradieShort(Job? job) {
    final full = job?.matchedTradieName?.trim();
    if (full == null || full.isEmpty) return 'the tradie';
    final first = full.split(' ').first;
    return first.isEmpty ? full : first;
  }

  static FixoBadgeKind _badgeKind(PaymentStage stage) => switch (stage) {
    PaymentStage.verified => FixoBadgeKind.done,
    PaymentStage.submitted => FixoBadgeKind.waiting,
    PaymentStage.rejected => FixoBadgeKind.problem,
    PaymentStage.expired => FixoBadgeKind.cancelled,
    PaymentStage.pending || PaymentStage.unknown => FixoBadgeKind.actionNeeded,
  };

  static String _method(String method) => switch (method) {
    'BankTransfer' => 'Bank transfer',
    _ => method.isEmpty ? 'Unavailable' : method,
  };
}
