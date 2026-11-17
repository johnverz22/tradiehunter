// Pure rules for the v2 homeowner jobs list (`ho_jobs`, migration plan 4.1 #2).
//
// Ports the filter and empty-state copy of views/jobs/jobs_list_screen.dart
// (homeowner branch) without importing it (lib/ui/** must not import v1).
import '../../models/marketplace.dart';
import 'ho_home_mapper.dart' show thIsPastHomeownerJob;

/// Same three filters as v1. The mockup draws Active / Completed only; "All"
/// stays because it is the only way to reach Cancelled / Expired jobs and the
/// v1 empty state links to it.
enum HoJobsFilter {
  active('Active'),
  completed('Completed'),
  all('All');

  const HoJobsFilter(this.label);
  final String label;
}

/// Jobs visible under [filter], server order preserved (v1 never re-sorted).
List<Job> thFilterHomeownerJobs(List<Job> jobs, HoJobsFilter filter) =>
    switch (filter) {
      HoJobsFilter.active =>
        jobs.where((j) => !thIsPastHomeownerJob(j.status)).toList(),
      HoJobsFilter.completed =>
        jobs.where((j) => j.status == 'Completed').toList(),
      HoJobsFilter.all => List<Job>.of(jobs),
    };

/// Title of the empty state shown when [filter] matches nothing.
String thJobsFilterEmptyTitle(HoJobsFilter filter) =>
    filter == HoJobsFilter.completed
    ? 'No completed jobs yet'
    : 'No active jobs';
