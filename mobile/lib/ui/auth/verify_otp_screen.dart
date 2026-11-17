// ThVerifyOtpScreen: v2 email-OTP verification (migration plan 3.2,
// id `verify_otp`).
//
// Hand-owned port of views/auth/otp_verification_screen.dart — same 60s
// resend cooldown (mirrors the backend's ResendCooldown), same auto-verify
// on the sixth digit, same static 'Resend code, on cooldown' semantics
// label, same keys (otp_screen / otp_code_field / verify_button /
// resend_button / change_email_button), same 'N digits to go' hint.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../feedback/th_notice.dart';

class ThVerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;

  const ThVerifyOtpScreen({super.key, required this.email});

  @override
  ConsumerState<ThVerifyOtpScreen> createState() => _ThVerifyOtpScreenState();
}

class _ThVerifyOtpScreenState extends ConsumerState<ThVerifyOtpScreen> {
  /// Matches the backend's `ResendCooldown` (AuthController, 60s).
  static const int _resendCooldownSeconds = 60;

  /// Matches THOtpInput's default length (and the backend's 6-digit code).
  static const int _codeLength = 6;

  final _codeController = TextEditingController();
  Timer? _countdownTimer;
  int _resendSecondsLeft = _resendCooldownSeconds;

  @override
  void initState() {
    super.initState();
    // The first code was just emailed, so start the cooldown immediately.
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _resendSecondsLeft = _resendCooldownSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  Future<void> _verify() async {
    if (ref.read(authViewModelProvider).isLoading) return;
    if (_codeController.text.length != _codeLength) {
      // Incomplete code — the "N digits to go" hint below the field is the
      // feedback, so there is nothing to send.
      FocusScope.of(context).unfocus();
      return;
    }
    FocusScope.of(context).unfocus();
    ref.read(authViewModelProvider.notifier).clearError();

    final success = await ref
        .read(authViewModelProvider.notifier)
        .verifyEmail(widget.email, _codeController.text);

    if (!success || !mounted) return;

    ref.invalidate(profileViewModelProvider);
    final destination = await getRoleRoute(
      ref.read(sharedProfileRepositoryProvider),
    );
    if (mounted) context.go(destination);
  }

  Future<void> _resend() async {
    if (_resendSecondsLeft != 0 || ref.read(authViewModelProvider).isLoading) {
      return;
    }
    ref.read(authViewModelProvider.notifier).clearError();
    final sent = await ref
        .read(authViewModelProvider.notifier)
        .resendOtp(widget.email);

    if (!mounted) return;

    // Restart the countdown either way: on success the new code must not be
    // spammed, and on a rejected resend (server cooldown or hourly cap) the
    // banner explains why while the button stays closed for another window.
    setState(_startCountdown);

    if (sent) {
      // A fresh code invalidates the previous one server-side.
      _codeController.clear();
      THNotice.info(context, NoticeCopy.codeSent(widget.email));
    }
  }

  int get _digitsRemaining => _codeLength - _codeController.text.length;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final canResend = _resendSecondsLeft == 0 && !authState.isLoading;

    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          final c = context.th;
          final th = c;
          return Scaffold(
            key: const Key('otp_screen'),
            backgroundColor: th.paper,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 480, // one-off: v1 auth form width
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s6),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: Space.s9),
                          THWordmark(),
                          const SizedBox(height: Space.s7),
                          Text(
                            'Check your email',
                            style: THType.h1.copyWith(
                              fontWeight: FontWeight.w700,
                              color: th.text,
                            ),
                          ),
                          const SizedBox(height: Space.s2),
                          Text(
                            'We sent a 6-digit code to',
                            style: THType.body.copyWith(color: th.textSoft),
                          ),
                          const SizedBox(height: Space.s1),
                          Text(
                            widget.email,
                            style: THType.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: th.text,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              key: const Key('change_email_button'),
                              onPressed: () => context.go('/auth'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(
                                  Sizes.tapMin,
                                  Sizes.tapMin,
                                ),
                              ),
                              child: Text(
                                'Use a different email',
                                style: THType.button.copyWith(
                                  color: th.textBrand,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.s4),
                          if (authState.error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Space.s4),
                              child: Semantics(
                                liveRegion: true,
                                child: Container(
                                  padding: const EdgeInsets.all(Space.s3),
                                  decoration: BoxDecoration(
                                    color: c.dangerTint,
                                    borderRadius: BorderRadius.circular(
                                      Radii.control,
                                    ),
                                    border: Border.all(
                                      color: c.danger,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    spacing: Space.s2_5,
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        size: Sizes.icon,
                                        color: c.danger,
                                      ),
                                      Expanded(
                                        child: Text(
                                          authState.error!,
                                          style: THType.meta.copyWith(
                                            color: c.danger,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Text(
                            'Verification code',
                            style: THType.label.copyWith(
                              color: th.textSoft,
                              fontSize: THType.railLabel.fontSize,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: Space.s2),
                          THOtpInput(
                            key: const Key('otp_code_field'),
                            controller: _codeController,
                            length: _codeLength,
                            enabled: !authState.isLoading,
                            onChanged: (_) => setState(() {}),
                            onCompleted: (_) => _verify(),
                          ),
                          const SizedBox(height: Space.s2),
                          Text(
                            _digitsRemaining <= 0
                                ? 'Code looks complete — tap Verify.'
                                : '$_digitsRemaining digit${_digitsRemaining == 1 ? '' : 's'} to go',
                            style: THType.meta.copyWith(color: th.textSoft),
                          ),
                          const SizedBox(height: Space.s4),
                          THButton(
                            key: const Key('verify_button'),
                            label: 'Verify email',
                            loading: authState.isLoading,
                            onPressed: _verify,
                          ),
                          const SizedBox(height: Space.s4),
                          SizedBox(
                            width: double.infinity,
                            // Static label — the per-second countdown below
                            // stays visible but excluded so assistive tech is
                            // not re-announced each tick.
                            child: Semantics(
                              button: true,
                              identifier: 'resend_button',
                              enabled: canResend,
                              label: canResend
                                  ? 'Resend code'
                                  : 'Resend code, on cooldown',
                              child: ExcludeSemantics(
                                child: TextButton(
                                  key: const Key('resend_button'),
                                  onPressed: canResend ? _resend : null,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(
                                      Sizes.tapMin,
                                      Sizes.tapMin,
                                    ),
                                    foregroundColor: th.textBrand,
                                    disabledForegroundColor: th.textSoft,
                                  ),
                                  child: Text(
                                    _resendSecondsLeft == 0
                                        ? 'Resend code'
                                        : 'Resend code in ${_resendSecondsLeft}s',
                                    style: THType.button.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.s9),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
