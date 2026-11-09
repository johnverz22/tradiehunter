#!/bin/bash
awk '
/var stage = job.Status switch/ {
    print "        var stage = job.Status switch"
    print "        {"
    print "            JobStatus.Requested          => 0,"
    print "            JobStatus.AwaitingPayment    => 1,"
    print "            JobStatus.PaymentReview      => 1,"
    print "            JobStatus.Booked             => 2,"
    print "            JobStatus.InProgress         => 3,"
    print "            JobStatus.AwaitingConfirmation => 4,"
    print "            JobStatus.Completed          => 5,"
    print "            _                            => 0,"
    print "        };"
    skip = 1
    next
}
skip && /};/ { skip = 0; next }
skip { next }
{ print }
' backend/Services/JobService.cs > backend/Services/JobService.cs.tmp
mv backend/Services/JobService.cs.tmp backend/Services/JobService.cs
