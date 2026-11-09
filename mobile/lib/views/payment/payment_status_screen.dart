import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/payment.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/payment_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../widgets/sticky_action_bar.dart';
import '../widgets/fixo_cta_stack.dart';


/// Payment status screen — H15 design (4 states: review / confirmed /
/// rejected / expired). Preserves all existing ViewModel wiring; only
/// the visual layout is updated.
class PaymentStatusScreen extends ConsumerStatefulWidget {
  final String jobId;
  const PaymentStatusScreen({super.key, required this.jobId});

  @override
  ConsumerState<PaymentStatusScreen> createState() =>
      _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends ConsumerState<PaymentStatusScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(paymentViewModelProvider(widget.jobId).notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(paymentViewModelProvider(widget.jobId));
    final payment = state.payment;

    return Scaffold(
      key: const Key('payment_status_screen'),
      appBar: const FixoAppBar(title: 'Payment status'),
      body: payment == null
          ? _loadingOrError(context, isDark, state)
          : _body(context, isDark, payment),
      bottomNavigationBar: payment == null
          ? null
          : StickyActionBar(child: _cta(context, payment)),
    );
  }

  // ── CTA per state ──────────────────────────────────────────────────────────

  Widget _cta(BuildContext context, PaymentStatus payment) {
    switch (payment.stage) {
      case PaymentStage.rejected:
        return FixoCtaStack(
          primaryKey: const Key('reupload_receipt_button'),
          primaryLabel: 'Upload again',
          onPrimary: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.push('/jobs/${widget.jobId}/payment');
            }
          },
          secondaryKey: const Key('back_to_job_button'),
          secondaryLabel: 'Back to job',
          onSecondary: () => context.go('/jobs/${widget.jobId}/detail'),
        );
      case PaymentStage.expired:
        return FixoCtaStack(
          primaryKey: const Key('start_again_button'),
          primaryLabel: 'Start again',
          onPrimary: () => context.go('/jobs/new'),
          secondaryKey: const Key('contact_support_button'),
          secondaryLabel: 'Contact support',
          onSecondary: () => context.push('/settings'),
        );
      default:
        return FixoPrimaryButton(
          key: const Key('back_to_job_button'),
          label: 'Back to job',
          onPressed: () => context.go('/jobs/${widget.jobId}/detail'),
        );
    }
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _loadingOrError(BuildContext context, bool isDark, PaymentState state) {
    if (state.error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(Space.s6),
      children: [
        Text(state.error!, style: TextStyle(color: DesignTokens.inkSoft(isDark))),
        const SizedBox(height: Space.s4),
        FixoGhostButton(
          label: 'Try again',
          onPressed: () =>
              ref.read(paymentViewModelProvider(widget.jobId).notifier).load(),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, bool isDark, PaymentStatus payment) {
    final isExpired = payment.stage == PaymentStage.expired;
    final isConfirmed = payment.stage == PaymentStage.verified;
    final isRejected = payment.stage == PaymentStage.rejected;

    // H15 hero visual per state
    final heroIcon = isRejected
        ? Icons.warning_amber_rounded
        : isConfirmed
        ? Icons.check_circle_rounded
        : Icons.access_time_rounded;

    final heroSize = isConfirmed ? 104.0 : 80.0;

    final heroBg = isRejected
        ? DesignTokens.red.withValues(alpha: Alpha.tintLight)
        : isConfirmed
        ? DesignTokens.green.withValues(alpha: Alpha.tintStandard)
        : DesignTokens.brand500.withValues(alpha: Alpha.tintStandard);

    final heroColor = isRejected
        ? DesignTokens.red
        : isConfirmed
        ? DesignTokens.green
        : DesignTokens.brand500;

    final headline = isExpired
        ? 'Payment window expired'
        : isConfirmed
        ? 'Payment verified'
        : isRejected
        ? 'We need a different receipt'
        : 'Under review';

    final body = isExpired
        ? 'This match has been released. Start again to find another tradie — your job details are saved.'
        : isConfirmed
        ? "Your payment has been verified. The job is booked."
        : isRejected
        ? (payment.rejectReason ??
              'The receipt was unclear — please upload a clearer photo or screenshot.')
        : "We're checking your receipt. This usually takes under a business day — we'll let you know.";

    final amountStr = NumberFormat.currency(symbol: r'$', decimalDigits: 2)
        .format(double.tryParse(payment.amount.toString()) ?? 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s6, Space.s7, Space.s6, Space.s6),
      children: [
        // ── Hero ────────────────────────────────────────────────────────────
        Center(
          child: isExpired
              ? Image.asset(
                  'assets/illustrations/il-05-${isDark ? 'dark' : 'light'}.png',
                  width: 196,
                )
              : Container(
                  width: heroSize,
                  height: heroSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: heroBg,
                  ),
                  child: Icon(heroIcon, size: heroSize * 0.45, color: heroColor),
                ),
        ),
        const SizedBox(height: 18),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: DesignTokens.fontDisplay,
            fontSize: DesignTokens.fontSizeH2,
            fontWeight: FW.bold,
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
        const SizedBox(height: Space.s2),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: DesignTokens.fontBody,
            fontSize: DesignTokens.fontSizeSm,
            height: 1.5,
            color: DesignTokens.inkSoft(isDark),
          ),
        ),
        if (isConfirmed) ...[
          const SizedBox(height: Space.s3),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.s2_5, vertical: Space.s1),
              decoration: BoxDecoration(
                color: DesignTokens.green.withValues(alpha: Alpha.tintStandard),
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: const Text(
                'Verified',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeCaption,
                  fontWeight: FW.semibold,
                  color: DesignTokens.green,
                ),
              ),
            ),
          ),
        ],
        if (isRejected &&
            payment.reUploadCount != null &&
            payment.reUploadCount! > 0) ...[
          const SizedBox(height: Space.s4),
          FixoCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sent back',
                  style: TextStyle(
                    fontFamily: DesignTokens.fontBody,
                    fontSize: DesignTokens.fontSizeSecondary,
                    color: DesignTokens.inkSoft(isDark),
                  ),
                ),
                Text(
                  '${payment.reUploadCount} times',
                  style: TextStyle(
                    fontFamily: DesignTokens.fontBody,
                    fontSize: DesignTokens.fontSizeSecondary,
                    fontWeight: FW.semibold,
                    color: DesignTokens.red,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.s6),

        // ── Review progress (when under review) ──────────────────────────────
        if (!isExpired && !isConfirmed && !isRejected) ...[
          Text(
            'Review progress',
            style: TextStyle(
              fontFamily: DesignTokens.fontDisplay,
              fontSize: DesignTokens.fontSizeH3,
              fontWeight: FW.bold,
              color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
            ),
          ),
          const SizedBox(height: Space.s2_5),
          FixoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: DesignTokens.green,
                    ),
                    const SizedBox(width: Space.s2),
                    Text(
                      'Receipt sent',
                      style: TextStyle(
                        fontFamily: DesignTokens.fontBody,
                        fontSize: DesignTokens.fontSizeSm,
                        fontWeight: FW.semibold,
                        color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.s2),
                Row(
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 16,
                      color: DesignTokens.amber,
                    ),
                    const SizedBox(width: Space.s2),
                    Text(
                      'Staff review',
                      style: TextStyle(
                        fontFamily: DesignTokens.fontBody,
                        fontSize: DesignTokens.fontSizeSm,
                        fontWeight: FW.semibold,
                        color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s5),
        ],

        // ── Amount + reference card (Receipt summary) ────────────────────────
        Text(
          'Receipt summary',
          style: TextStyle(
            fontFamily: DesignTokens.fontDisplay,
            fontSize: DesignTokens.fontSizeH3,
            fontWeight: FW.bold,
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
        const SizedBox(height: Space.s2_5),
        FixoCard(
          child: Column(
            children: [
              _row(isDark, isConfirmed ? 'Paid' : 'Amount', amountStr),
              _divider(isDark),
              _row(isDark, 'Reference', payment.reference, mono: true),
            ],
          ),
        ),

        // ── Receipt link ────────────────────────────────────────────────────
        if (!isExpired) ...[
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: () => context.push('/jobs/${widget.jobId}/payment'),
              child: Text(
                'View receipt details',
                style: TextStyle(
                  fontFamily: DesignTokens.fontBody,
                  fontSize: DesignTokens.fontSizeSm,
                  fontWeight: FW.semibold,
                  color: DesignTokens.foregroundBrand(isDark),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _divider(bool isDark) => Divider(
    height: 20,
    color: isDark ? DesignTokens.paperLineDark : DesignTokens.paperLineLight,
  );

  Widget _row(bool isDark, String label, String value, {bool mono = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: DesignTokens.fontBody,
            fontSize: DesignTokens.fontSizeSm,
            color: DesignTokens.inkSoft(isDark),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: mono ? DesignTokens.fontMono : DesignTokens.fontBody,
            fontSize: DesignTokens.fontSizeSm,
            fontWeight: FW.semibold,
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
      ],
    );
  }
}
