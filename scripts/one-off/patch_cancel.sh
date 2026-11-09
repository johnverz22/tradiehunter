#!/bin/bash
awk '
/public async Task<IActionResult> CancelJobWithReason/ { in_cancel = 1 }
in_cancel && /null, null/ {
    sub(/null, null/, "null, request.Reason")
    in_cancel = 0
}
{ print }
' backend/Controllers/JobsController.cs > backend/Controllers/JobsController.cs.tmp
mv backend/Controllers/JobsController.cs.tmp backend/Controllers/JobsController.cs
