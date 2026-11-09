#!/bin/bash
awk '
/await _jobStatusService.TransitionAsync\(id, JobStatus.Cancelled, userId, role, null, request.Reason\);/ {
    print "                var dto = await _jobStatusService.TransitionAsync(id, JobStatus.Cancelled, userId, role, null, request.Reason);"
    next
}
{print}
' backend/Controllers/JobsController.cs > backend/Controllers/JobsController.cs.tmp
mv backend/Controllers/JobsController.cs.tmp backend/Controllers/JobsController.cs
