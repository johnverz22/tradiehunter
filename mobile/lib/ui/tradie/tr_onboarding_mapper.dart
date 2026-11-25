import '../../models/tradie_onboarding.dart';

const List<String> trOnboardingStepTitles = [
  'Where you work',
  'Trades',
  'Verification',
  'Payout',
];

const List<String> trOnboardingStepSubtitles = [
  'Step 1 of 4 · Where you work',
  'Step 2 of 4 · Trades',
  'Step 3 of 4 · Credentials',
  'Step 4 of 4 · Payout',
];

const Map<int, String> trOnboardingDayNames = {
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  0: 'Sunday',
};

String trOnboardingCtaLabel(int step, {required bool isSaving}) {
  if (step >= 3) {
    return isSaving ? 'Finishing…' : 'Finish setup';
  }
  return isSaving ? 'Saving…' : 'Continue';
}

String trCredentialStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'verified':
    case 'approved':
      return 'Verified';
    case 'rejected':
      return 'Rejected';
    default:
      return 'Pending';
  }
}

List<int> trOnboardingSortedDays(Map<int, TradieScheduleSlot> schedule) {
  return const [1, 2, 3, 4, 5, 6, 0];
}
