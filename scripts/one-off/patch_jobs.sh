#!/bin/bash
sed -i '' -e 's/await _jobStatusService.TransitionAsync(id, JobStatus.InProgress, userId);/await _jobStatusService.TransitionAsync(id, JobStatus.InProgress, userId, UserRole.Tradie);/g' backend/Controllers/JobsController.cs
sed -i '' -e 's/await _jobStatusService.TransitionAsync(id, JobStatus.Completed, userId);/await _jobStatusService.TransitionAsync(id, JobStatus.Completed, userId, UserRole.Homeowner);/g' backend/Controllers/JobsController.cs
sed -i '' -e 's/await _jobStatusService.TransitionAsync(/await _jobStatusService.TransitionAsync(/g' backend/Controllers/JobsController.cs
