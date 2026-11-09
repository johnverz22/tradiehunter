#!/bin/bash
awk '
/id, JobStatus.Cancelled, userId, request.Reason/ {
    print "                var role = job.HomeownerId == userId ? UserRole.Homeowner : UserRole.Tradie;"
    print "                var dto = await _jobStatusService.TransitionAsync(id, JobStatus.Cancelled, userId, role, null, request.Reason);"
    next
}
{print}
' backend/Controllers/JobsController.cs > backend/Controllers/JobsController.cs.tmp
mv backend/Controllers/JobsController.cs.tmp backend/Controllers/JobsController.cs
