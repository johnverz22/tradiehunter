import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/jobs_viewmodel.dart';

const int thTitleMaxLength = 200;
const int thDescriptionMaxLength = 2000;
const int thScopeNotesMaxLength = 2000;
const int thAddressMaxLength = 160;
const int thMaxPhotos = 5;
const int thMaxPhotoBytes = 10 * 1024 * 1024;

class PostJobCopy {
  const PostJobCopy({
    required this.subtitle,
    required this.modeHint,
    required this.titleLabel,
    required this.titleHint,
    required this.descriptionLabel,
    required this.descriptionHint,
    required this.buttonLabel,
  });

  final String subtitle;
  final String modeHint;
  final String titleLabel;
  final String titleHint;
  final String descriptionLabel;
  final String descriptionHint;
  final String buttonLabel;
}

PostJobCopy thPostJobCopy(String jobType, {bool openToBoard = true}) {
  if (jobType == Job.jobTypeProject) {
    return PostJobCopy(
      subtitle: openToBoard
          ? 'Get quotes from nearby tradies'
          : 'Get up to 3 quotes',
      modeHint: 'Project = tradies send you a quote',
      titleLabel: 'PROJECT SUMMARY',
      titleHint: 'e.g. Kitchen renovation',
      descriptionLabel: 'SCOPE',
      descriptionHint: 'What needs doing, what stays as it is…',
      buttonLabel: openToBoard ? 'Post project' : 'Request up to 3 quotes',
    );
  }
  return const PostJobCopy(
    subtitle: 'Describe it. No price needed yet.',
    modeHint: 'Quick job = hourly rate, pay when done',
    titleLabel: 'JOB TITLE',
    titleHint: 'e.g. Fix a leaking kitchen tap',
    descriptionLabel: 'DESCRIPTION',
    descriptionHint: 'e.g. Leaking kitchen tap, drips constantly…',
    buttonLabel: 'Choose a tradie',
  );
}

String? thMissingFieldHelper(PostJobState state) {
  if (state.submittedJobId != null) return null;
  if (state.selectedService == null) {
    return 'Select a service to post your job';
  }
  if (state.resolvedAddress == null) {
    return 'Select a job address to post your job';
  }
  if (state.title.trim().isEmpty) {
    return 'Add a title to post your job';
  }
  if (state.description.trim().isEmpty) {
    return 'Add a description to post your job';
  }
  if (state.timingPreference == 'SpecificDate' &&
      state.scheduledStartLocal == null) {
    return 'Pick a start date to post your job';
  }
  if (state.timingPreference == 'DateRange') {
    if (state.scheduledStartLocal == null) {
      return 'Pick a start date to post your job';
    }
    if (state.scheduledEndLocal == null) {
      return 'Pick an end date to post your job';
    }
  }
  return null;
}

String thFormatHours(double hours) => hours == hours.roundToDouble()
    ? hours.round().toString()
    : hours.toString();

bool thShowCounter(int length, int maxLength) =>
    maxLength > 0 && length >= (maxLength * 0.8).ceil();

String thUrgencyMeaning(String urgency) => switch (urgency) {
  'Low' => 'Flexible timing · needed within the next week or two',
  'Medium' => 'Standard priority · needed within the next few days',
  'High' => 'High priority · needed within 24–48 hours',
  'Emergency' => 'Immediate response · needed today or ASAP',
  _ => '',
};

class ThTimingOption {
  const ThTimingOption({
    required this.wireValue,
    required this.label,
    required this.helper,
    this.icon,
  });

  final String wireValue;
  final String label;
  final String helper;
  final IconData? icon;
}

List<ThTimingOption> thTimingOptions(String jobType) => const [
  ThTimingOption(
    wireValue: 'Flexible',
    label: 'Flexible',
    helper: 'Any time that suits the tradie\'s schedule',
  ),
  ThTimingOption(
    wireValue: 'Asap',
    label: 'ASAP',
    helper: 'As soon as a tradie can get here',
  ),
  ThTimingOption(
    wireValue: 'SpecificDate',
    label: 'Pick a date',
    helper: 'Choose a start date and time',
  ),
  ThTimingOption(
    wireValue: 'DateRange',
    label: 'Date range',
    helper: 'Choose a start and end window',
  ),
];

String thTimingHelper(String wireValue) {
  for (final option in thTimingOptions(Job.jobTypeHourly)) {
    if (option.wireValue == wireValue) return option.helper;
  }
  return '';
}

String thBudgetSummary(Decimal? min, Decimal? max) {
  if (min != null && max != null) return '\$$min – \$$max';
  if (min != null) return 'From \$$min';
  if (max != null) return 'Up to \$$max';
  return 'Not set';
}

String thReviewSummaryTitle(String jobType) =>
    jobType == Job.jobTypeProject ? 'Project summary' : 'Quick job summary';

String thReviewPricingNote(String jobType) => jobType == Job.jobTypeProject
    ? 'Tradies will send you quotes to compare.'
    : 'You agree the hourly rate, then pay when the job is done.';

const String thReviewMaterialsNote =
    'Materials are added in-app and need your approval. '
    'The total is confirmed when the job is done.';

enum ThReviewRowKind { job, location, when, budget }

class ThReviewRow {
  const ThReviewRow({
    required this.kind,
    required this.label,
    this.value = '',
    this.when,
    this.placeholder = false,
  });

  final ThReviewRowKind kind;
  final String label;
  final String value;
  final DateTime? when;
  final bool placeholder;
}

List<ThReviewRow> thReviewRows(PostJobState state) {
  final rows = <ThReviewRow>[
    ThReviewRow(
      kind: ThReviewRowKind.job,
      label: 'Job',
      value: state.title.trim().isEmpty
          ? 'Add a job title above'
          : state.title.trim(),
      placeholder: state.title.trim().isEmpty,
    ),
    ThReviewRow(
      kind: ThReviewRowKind.location,
      label: 'Location',
      value: state.resolvedAddress?.address ?? 'Choose an address result above',
      placeholder: state.resolvedAddress == null,
    ),
  ];
  if (state.scheduledStartLocal != null) {
    rows.add(
      ThReviewRow(
        kind: ThReviewRowKind.when,
        label: 'When',
        when: state.scheduledStartLocal,
      ),
    );
  }
  if (state.isProject && (state.budgetMin != null || state.budgetMax != null)) {
    rows.add(
      ThReviewRow(
        kind: ThReviewRowKind.budget,
        label: 'Budget',
        value: thBudgetSummary(state.budgetMin, state.budgetMax),
      ),
    );
  }
  return rows;
}

bool thPhotoTooLarge(int bytes) => bytes > thMaxPhotoBytes;
