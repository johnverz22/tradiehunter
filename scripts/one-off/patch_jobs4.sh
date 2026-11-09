#!/bin/bash
awk '
BEGIN { in_checkin = 0; in_complete = 0 }
/public async Task<IActionResult> CheckInJob/ { in_checkin = 1; print; next }
/public async Task<IActionResult> CompleteJob/ { in_complete = 1; print; next }

in_checkin && /var role = job.HomeownerId == userId \? UserRole.Homeowner : UserRole.Tradie;/ { skip = 1; next }
in_checkin && /var dto = await _jobStatusService.TransitionAsync\(id, JobStatus.Cancelled, userId, role, null, request.Reason\);/ {
    print "            var dto = await _jobStatusService.TransitionAsync(id, JobStatus.InProgress, userId, UserRole.Tradie);"
    in_checkin = 0
    next
}

in_complete && /var role = job.HomeownerId == userId \? UserRole.Homeowner : UserRole.Tradie;/ { skip = 1; next }
in_complete && /var dto = await _jobStatusService.TransitionAsync\(id, JobStatus.Cancelled, userId, role, null, request.Reason\);/ {
    print "            var dto = await _jobStatusService.TransitionAsync(id, JobStatus.Completed, userId, UserRole.Homeowner);"
    in_complete = 0
    next
}

{ print }
' backend/Controllers/JobsController.cs > backend/Controllers/JobsController.cs.tmp
mv backend/Controllers/JobsController.cs.tmp backend/Controllers/JobsController.cs
