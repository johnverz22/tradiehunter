import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../widgets/otp_code_field.dart';
import '../widgets/auth_controls.dart';
import '../widgets/fixo_feedback.dart';


/// P1-08: email OTP entry. Reached from signup (registration always leaves
/// the account unverified) and from login when the backend answers
/// 403 `{ requiresVerification: true }`.
///
///   context.go('/verify-email', extra: email)
///
/// Shows the 6-digit field, an amber Verify CTA and a 60s resend
/// countdown that mirrors the backend's `ResendCooldown`.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  /// Matches the backend's `ResendCooldown` (AuthController, 60s).
  static const int _resendCooldownSeconds = 60;

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
    if (_codeController.text.length != OtpCodeField.length) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('New code sent to ${widget.email}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canResend = _resendSecondsLeft == 0 && !authState.isLoading;

    return Scaffold(
      key: const Key('otp_screen'),
      body: SafeArea(
        child: AuthScrollView(
          padding: const EdgeInsets.fromLTRB(Space.s6, 48, Space.s6, Space.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FixoWordmark(fontSize: DesignTokens.fontSizeDisplay),
              const SizedBox(height: Space.s7),
              Text(
                'Check your email',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FW.bold,
                ),
              ),
              const SizedBox(height: Space.s2),
              Text(
                'We sent a 6-digit code to',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? DesignTokens.inkSoftDark
                      : DesignTokens.inkSoftLight,
                ),
              ),
              const SizedBox(height: Space.s1),
              Text(
                widget.email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: DesignTokens.fontBody,
                  fontSize: DesignTokens.fontSizeBody,
                  fontWeight: FW.semibold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: Space.s7),
              if (authState.error != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Space.s4),
                    child: FixoInfoBanner.error(message: authState.error!),
                  ),
                ),
              const Text(
                'Verification code',
                style: TextStyle(fontSize: DesignTokens.fontSizeSm, fontWeight: FW.medium),
              ),
              const SizedBox(height: Space.s2),
              Center(
                child: OtpCodeField(
                  key: const Key('otp_code_field'),
                  controller: _codeController,
                  enabled: !authState.isLoading,
                  onChanged: (_) => setState(() {}),
                  onCompleted: (_) => _verify(),
                ),
              ),
              const SizedBox(height: Space.s2),
              _DigitsRemaining(count: _digitsRemaining),
              const SizedBox(height: Space.s4),
              FixoPrimaryButton(
                key: const Key('verify_button'),
                label: 'Verify email',
                isLoading: authState.isLoading,
                onPressed: _verify,
              ),
              const SizedBox(height: Space.s4),
              SizedBox(
                width: double.infinity,
                // Static label — the per-second countdown below stays visible
                // but excluded so assistive tech is not re-announced each tick.
                child: Semantics(
                  button: true,
                  enabled: canResend,
                  label: canResend ? 'Resend code' : 'Resend code, on cooldown',
                  child: ExcludeSemantics(
                    child: TextButton(
                      key: const Key('resend_button'),
                      onPressed: canResend ? _resend : null,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, 48),
                        foregroundColor: theme.colorScheme.primary,
                        disabledForegroundColor:
                            theme.colorScheme.onSurfaceVariant,
                      ),
                      child: Text(
                        _resendSecondsLeft == 0
                            ? 'Resend code'
                            : 'Resend code in ${_resendSecondsLeft}s',
                        style: const TextStyle(
                          fontSize: DesignTokens.fontSizeSm,
                          fontWeight: FW.semibold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.s7),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Wrong address?'),
                  TextButton(
                    onPressed: () => context.go('/auth'),
                    child: const Text('Use a different account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _digitsRemaining => OtpCodeField.length - _codeController.text.length;
}

/// "4 digits to go" hint under the code field. Always rendered so tapping
/// Verify with an incomplete code is never a dead action.
class _DigitsRemaining extends StatelessWidget {
  final int count;

  const _DigitsRemaining({required this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      count <= 0
          ? 'Code looks complete — tap Verify.'
          : '$count digit${count == 1 ? '' : 's'} to go',
      style: TextStyle(
        fontSize: DesignTokens.fontSizeSm,
        color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
      ),
    );
  }
}

