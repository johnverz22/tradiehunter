import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../feedback/fixo_notice.dart';
import '../../models/marketplace.dart';
import '../../models/payment.dart';
import '../../utils/money.dart';
import '../../viewmodels/locale_viewmodel.dart';
import '../../viewmodels/payment_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoPaymentScreen extends ConsumerStatefulWidget {
  const HoPaymentScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<HoPaymentScreen> createState() => _HoPaymentScreenState();
}

class _HoPaymentScreenState extends ConsumerState<HoPaymentScreen> {
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(paymentViewModelProvider(widget.jobId).notifier).load(),
    );
  }

  Future<void> _upload() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    final ok = await ref
        .read(paymentViewModelProvider(widget.jobId).notifier)
        .uploadReceipt(picked.path);
    if (!mounted) return;
    if (ok) await context.push('/jobs/${widget.jobId}/payment/status');
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      FixoNotice.info(context, '$label copied.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentViewModelProvider(widget.jobId));
    final payment = state.payment;
    final bank = payment?.bankDetails;
    final bankReady = bank?.isAvailable ?? false;
    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: THScaffold(
        key: const Key('payment_screen'),
        appBar: THAppBar(title: 'Payment', subtitle: payment?.jobTitle),
        stickyBar: payment?.canUploadReceipt == true
            ? THStickyBar(
                children: [
                  if (!bankReady) ...[
                    const THText(
                      'Upload is available once valid bank details are shown.',
                      key: Key('upload_disabled_hint'),
                      style: THTextStyle.meta,
                      align: TextAlign.center,
                    ),
                    const SizedBox(height: Space.s2),
                    THButton(
                      label: state.isLoading
                          ? 'Refreshing…'
                          : 'Refresh payment details',
                      loading: state.isLoading,
                      onPressed: () => ref
                          .read(paymentViewModelProvider(widget.jobId).notifier)
                          .load(),
                    ),
                  ] else
                    THButton(
                      key: const Key('upload_receipt_button'),
                      label: state.isUploading
                          ? 'Uploading…'
                          : 'Upload bank receipt',
                      kind: THButtonKind.accent,
                      loading: state.isUploading,
                      onPressed: _upload,
                    ),
                ],
              )
            : null,
        scrollable: true,
        body: state.isLoading && payment == null
            ? const Center(child: CircularProgressIndicator())
            : payment == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  THText(
                    state.error ?? 'Payment details are unavailable.',
                    tone: THTone.danger,
                  ),
                  const SizedBox(height: Space.s3),
                  THButton(
                    label: 'Try again',
                    kind: THButtonKind.secondary,
                    onPressed: () => ref
                        .read(paymentViewModelProvider(widget.jobId).notifier)
                        .load(),
                  ),
                ],
              )
            : _details(context, state, payment, bankReady),
      ),
    );
  }

  Widget _details(
    BuildContext context,
    PaymentState state,
    PaymentStatus payment,
    bool bankReady,
  ) {
    final job = ref.watch(paymentJobProvider(widget.jobId)).valueOrNull;
    final bank = payment.bankDetails;
    final locale = ref.watch(localeConfigProvider).valueOrNull;
    final disclaimer = locale?['materialsDisclaimer'] as String?;
    final hasLabour = job?.labourAmount != null;
    final hasLegacy = job != null && job.hours > 0 && job.hourlyRate != null;
    final adjustments = job?.adjustmentsTotal;
    final hasExtras = adjustments != null && adjustments > Decimal.zero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s3,
      children: [
        if (payment.stage != PaymentStage.pending)
          THBadge(
            payment.stage.label,
            kind: payment.stage == PaymentStage.verified
                ? THBadgeKind.ok
                : payment.stage == PaymentStage.rejected ||
                      payment.stage == PaymentStage.expired
                ? THBadgeKind.danger
                : THBadgeKind.accent,
          ),
        if (state.error != null) THText(state.error!, tone: THTone.danger),
        THHero(
          children: [
            const THText(
              'AMOUNT TO PAY',
              style: THTextStyle.label,
              tone: THTone.gold,
            ),
            const SizedBox(height: Space.s2),
            THText(
              formatMoney(payment.amount),
              style: THTextStyle.moneyLg,
              tone: THTone.onHero,
            ),
            THText(
              '${payment.currency} · incl. GST',
              style: THTextStyle.meta,
              tone: THTone.onHeroSoft,
            ),
          ],
        ),
        THCard(
          children: [
            if (hasLabour)
              THKeyValue(
                _labourLabel(job!),
                formatMoney(job.labourAmount!),
                bold: true,
              )
            else if (hasLegacy)
              THKeyValue(
                _labourLabel(job),
                formatMoney(job.hourlyRate! * Decimal.fromInt(job.hours)),
                bold: true,
              ),
            if (hasExtras)
              THKeyValue(
                'Approved extras',
                formatMoney(adjustments),
                bold: true,
                divider: true,
              ),
            THKeyValue(
              'Job total',
              formatMoney(payment.amount),
              bold: true,
              strong: true,
              divider: hasLabour || hasLegacy || hasExtras,
            ),
          ],
        ),
        if (disclaimer?.isNotEmpty == true)
          THCard(
            tone: THCardTone.accent,
            children: [THText(disclaimer!, style: THTextStyle.meta)],
          ),
        if (bankReady) ...[
          THCard(
            children: [
              THKeyValue('Account name', bank!.accountName, bold: true),
              THKeyValue(
                'Account number',
                bank.accountNumber,
                bold: true,
                divider: true,
              ),
              InkWell(
                key: const Key('copy_reference_button'),
                onTap: () => _copy(payment.reference, 'Reference'),
                child: THKeyValue(
                  'Reference',
                  payment.reference,
                  bold: true,
                  divider: true,
                  copy: true,
                ),
              ),
            ],
          ),
          if (payment.canUploadReceipt)
            InkWell(
              key: const Key('upload_receipt_box'),
              onTap: state.isUploading ? null : _upload,
              borderRadius: BorderRadius.circular(Radii.tile),
              child: const THDashBox(
                icon: Icons.upload_rounded,
                title: 'Upload your receipt',
                subtitle: 'Staff verify it, then the job completes',
              ),
            ),
        ]
        else
          THCard(
            tone: THCardTone.danger,
            children: [
              const THText(
                'Bank transfer details are unavailable. Do not transfer money until valid instructions are shown.',
                tone: THTone.danger,
              ),
            ],
          ),
        if (payment.stage == PaymentStage.rejected)
          THCard(
            tone: THCardTone.danger,
            children: [
              const THText(
                'Receipt needs another look',
                style: THTextStyle.title,
                tone: THTone.danger,
              ),
              THText(
                payment.rejectReason ?? 'The receipt could not be accepted.',
                tone: THTone.soft,
              ),
              if (payment.reUploadCount > 0)
                THText(
                  'Sent back ${payment.reUploadCount} ${payment.reUploadCount == 1 ? 'time' : 'times'}.',
                  style: THTextStyle.meta,
                ),
            ],
          ),
      ],
    );
  }

  /// "Labour · 2.5 h × $85" (mockup ho_payment). Falls back to "Labour" when
  /// hours or rate are missing; never invents a figure.
  String _labourLabel(Job job) {
    final hours = job.finalHours ?? job.estimatedHours ?? job.hours.toDouble();
    final rate = job.hourlyRate;
    if (hours <= 0 || rate == null) return 'Labour';
    final h = hours == hours.roundToDouble()
        ? hours.toInt().toString()
        : hours.toString();
    final r = formatMoney(rate).replaceFirst(RegExp(r'\.00$'), '');
    return 'Labour · $h h × $r';
  }
}

class HoPaymentStatusScreen extends ConsumerStatefulWidget {
  const HoPaymentStatusScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<HoPaymentStatusScreen> createState() =>
      _HoPaymentStatusScreenState();
}

class _HoPaymentStatusScreenState extends ConsumerState<HoPaymentStatusScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(paymentViewModelProvider(widget.jobId).notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentViewModelProvider(widget.jobId));
    final payment = state.payment;
    // Status is a post-submission view. While the transfer is still pending
    // the payment screen is the one place to act, so never show a "status"
    // sub-screen for it.
    if (payment?.stage == PaymentStage.pending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement('/jobs/${widget.jobId}/payment');
      });
    }
    final isV2 =
        ref.watch(paymentJobProvider(widget.jobId)).valueOrNull?.usesV2Flow ??
        true;
    final stage = payment?.stage;
    final title = switch (stage) {
      PaymentStage.verified => 'Payment confirmed',
      PaymentStage.rejected => 'Receipt needs another look',
      PaymentStage.expired => 'Payment window expired',
      PaymentStage.submitted => 'Receipt sent for review',
      _ => 'Payment status',
    };
    final description = switch (stage) {
      PaymentStage.verified =>
        isV2
            ? 'Your payment has been verified and the completed work is settled.'
            : 'Your payment has been verified. The job is booked with your tradie.',
      PaymentStage.rejected =>
        payment?.rejectReason ?? 'Please upload a clearer receipt.',
      PaymentStage.expired =>
        isV2
            ? 'The payment window closed without a receipt. Contact support for help.'
            : 'This match has been released. Start again to find another tradie.',
      PaymentStage.submitted => 'Our team is checking your receipt. We usually verify within one business day.',
      _ => state.error ?? 'Payment status is unavailable.',
    };
    final kind = stage == PaymentStage.verified
        ? THBadgeKind.ok
        : stage == PaymentStage.rejected || stage == PaymentStage.expired
        ? THBadgeKind.danger
        : THBadgeKind.accent;
    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: THScaffold(
        key: const Key('payment_status_screen'),
        appBar: const THAppBar(title: 'Payment status'),
        stickyBar: payment == null
            ? null
            : THStickyBar(
                children: [
                  if (stage == PaymentStage.rejected)
                    THButton(
                      label: 'Upload again',
                      kind: THButtonKind.accent,
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.push('/jobs/${widget.jobId}/payment');
                        }
                      },
                    ),
                  if (stage == PaymentStage.expired && isV2)
                    THButton(
                      label: 'Contact support',
                      onPressed: () => context.push('/settings'),
                    ),
                  THButton(
                    label: 'Back to job',
                    kind: THButtonKind.secondary,
                    onPressed: () => context.go('/jobs/${widget.jobId}/detail'),
                  ),
                ],
              ),
        scrollable: true,
        body: payment == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  THText(
                    state.error ?? 'Loading payment status…',
                    tone: state.error == null ? THTone.soft : THTone.danger,
                  ),
                  if (state.error != null)
                    THButton(
                      label: 'Try again',
                      kind: THButtonKind.secondary,
                      onPressed: () => ref
                          .read(paymentViewModelProvider(widget.jobId).notifier)
                          .load(),
                    ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: Space.s3,
                children: [
                  const SizedBox(height: Space.s3),
                  THBadge(title, kind: kind),
                  THText(
                    description,
                    style: THTextStyle.body,
                    tone: THTone.soft,
                  ),
                  THCard(
                    children: [
                      THKeyValue(
                        'Amount',
                        formatMoney(payment.amount),
                        bold: true,
                      ),
                      THKeyValue(
                        'Reference',
                        payment.reference,
                        bold: true,
                        divider: true,
                      ),
                      THKeyValue(
                        'Status',
                        payment.stage.label,
                        badge: stage == PaymentStage.verified
                            ? THBadgeKind.ok
                            : kind,
                        divider: true,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
