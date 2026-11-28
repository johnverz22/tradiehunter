// All user-visible notice strings for the THNotice system.
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
  static const String noCallApp = 'No app available to make the call.';
  static const String noOtherUser = 'No other user on this job yet.';
  static const String userBlocked = 'User blocked.';
  static const String reportSent = 'Thanks — our team will review this report.';
  static const String photoUnavailable =
      'Photo attachments are not available in chat.';

  // ── Homeowner job detail ──────────────────────────────────────────────────
  static const String jobCancelled = 'Job cancelled.';
  static const String noShowReported = 'No-show reported successfully.';
  static const String noShowFailed =
      'Could not report no-show. Please try again.';
  static const String cancelFailed =
      'Could not cancel the job. Please try again.';

  // ── Tradie job detail ─────────────────────────────────────────────────────
  static const String checkInFailed = 'Check-in failed. Please try again.';
  static const String checkOutFailed = 'Check-out failed. Please try again.';
  static const String markDoneFailed =
      'Could not mark job as done. Please try again.';

  // ── Tradie request / offer ────────────────────────────────────────────────
  static const String offerDeclineFailed =
      'Could not decline — please try again.';
  static const String offerAcceptFailed =
      'Could not accept — please try again.';
  static const String offerAccepted = 'Request accepted — the job is booked.';
  static const String notificationsOff =
      'Notifications are off. Turn them on in Settings to be alerted when the app is closed.';
  static const String offerNoLongerAvailable =
      'This request is no longer available.';
  static const String offerWithdrawn =
      'Request withdrawn — pick another tradie.';

  /// Maps a backend `ApiError.code` from an offer accept/decline 409 to
  /// concise user-facing copy (QA plan §2C/§2E).
  static String forOfferError(String? code, {required bool accept}) =>
      switch (code) {
        'offer_expired' => 'This offer has expired.',
        'job_already_booked' => 'Another tradie already took this job.',
        'job_not_requestable' => 'This job is no longer open.',
        'offer_not_pending' => offerNoLongerAvailable,
        _ => accept ? offerAcceptFailed : offerDeclineFailed,
      };

  /// Maps a backend `ApiError.code` from a homeowner direct-request 409 to
  /// concise user-facing copy (QA plan §2C/§2D).
  static String forRequestError(String? code) => switch (code) {
    'job_already_booked' => 'This job is already booked.',
    'job_not_requestable' => 'This job is no longer open.',
    'pending_request_exists' =>
      'You already have a pending request for this job.',
    'tradie_already_declined' => 'This tradie already declined — pick another.',
    'tradie_unreachable' => 'That tradie just went offline — pick another.',
    _ => requestFailed,
  };

  // ── Profile ───────────────────────────────────────────────────────────────
  static const String profileUpdated = 'Profile updated successfully.';
  static const String reviewsLocked = 'Reviews unlock after a completed job.';
  static const String requestFailed = 'Could not send the request. Try again.';

  // ── Auth / OTP ────────────────────────────────────────────────────────────
  static const String loginError = 'Login failed. Check your credentials.';

  // ── Tradie dashboard ──────────────────────────────────────────────────────
  static const String statusUpdateFailed =
      'Could not update availability. Try again.';

  // ── Tradie onboarding ─────────────────────────────────────────────────────
  static const String onboardingSaveFailed =
      'Could not save — please try again.';

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
