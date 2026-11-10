// All user-visible notice strings for the FixoNotice system.
//
// Rules:
//   • Sentence case.
//   • Active voice.
//   • ≤ 80 characters per string.
//   • Never inline these literals at call sites — always import NoticeCopy.
//
// See: docs/design/feedback-guidelines.md

/// Centralised copy for all in-app notice (toast) messages.
abstract class NoticeCopy {
  NoticeCopy._();

  // ── Clipboard ────────────────────────────────────────────────────────────
  static const String copied = 'Copied to clipboard.';

  // ── Chat ─────────────────────────────────────────────────────────────────
  static const String noCallApp       = 'No app available to make the call.';
  static const String noOtherUser     = 'No other user on this job yet.';
  static const String userBlocked     = 'User blocked.';
  static const String reportSent      = 'Thanks — our team will review this report.';
  static const String photoUnavailable = 'Photo attachments are not available in chat.';

  // ── Homeowner job detail ──────────────────────────────────────────────────
  static const String jobCancelled    = 'Job cancelled.';
  static const String noShowReported  = 'No-show reported successfully.';
  static const String noShowFailed    = 'Could not report no-show. Please try again.';
  static const String cancelFailed    = 'Could not cancel the job. Please try again.';

  // ── Tradie job detail ─────────────────────────────────────────────────────
  static const String checkInFailed   = 'Check-in failed. Please try again.';
  static const String checkOutFailed  = 'Check-out failed. Please try again.';
  static const String markDoneFailed  = 'Could not mark job as done. Please try again.';

  // ── Tradie request / offer ────────────────────────────────────────────────
  static const String offerDeclineFailed = 'Could not decline — please try again.';
  static const String offerAcceptFailed  = 'Could not accept — please try again.';

  // ── Profile ───────────────────────────────────────────────────────────────
  static const String profileUpdated  = 'Profile updated successfully.';
  static const String reviewsLocked   = 'Reviews unlock after a completed job.';
  static const String requestFailed   = 'Could not send the request. Try again.';

  // ── Auth / OTP ────────────────────────────────────────────────────────────
  static const String loginError      = 'Login failed. Check your credentials.';

  // ── Tradie dashboard ──────────────────────────────────────────────────────
  static const String statusUpdateFailed = 'Could not update availability. Try again.';

  // ── Tradie onboarding ─────────────────────────────────────────────────────
  static const String onboardingSaveFailed = 'Could not save — please try again.';

  // ── Payment ───────────────────────────────────────────────────────────────
  // (payment_screen passes a dynamic `message` from backend — see dynamic getters below)

  // ── Dynamic (computed at call site) ──────────────────────────────────────

  /// OTP resend confirmation: "New code sent to alice@example.com".
  static String codeSent(String email) => 'New code sent to $email.';

  /// Stub for unimplemented settings rows: "Language is not available in this app."
  static String stubUnavailable(String label) =>
      '$label is not available in this app.';

  /// Tradie dashboard new-job banner headline.
  static String newJobRequest(String title) => 'New Job Request: $title';

  /// Tradie dashboard online-status toggle feedback.
  static String onlineStatusChanged({required bool online}) =>
      'You are now ${online ? 'online' : 'offline'}.';
}
