# Runbook: SLO burn-rate alert fired

Alerts: `sre-platform-dev-slo-page-fast`, `sre-platform-dev-slo-page-slow`,
`sre-platform-dev-slo-latency-p99`.

## 1. Decide how bad it is (2 minutes)

- Open the CloudWatch dashboard `sre-platform-dev-slo`.
- Which alert? Fast burn means users are failing right now. Slow burn means a smaller problem that
  has lasted for hours.
- Is the 5xx ratio still above the budget line, or already back under it?

## 2. Find the layer

| Dashboard shows | Likely layer | Check |
|---|---|---|
| Target 5xx up, healthy targets normal | The application | Container logs: `aws logs tail /ecs/sre-platform-dev --since 30m` |
| Load balancer 5xx up, healthy targets 0 | Tasks not passing health checks | ECS service events, target group health reasons |
| Healthy targets dropping then recovering | A deployment or tasks restarting | ECS deployments tab; circuit breaker events |
| Latency up, errors flat | Saturation or the database | CPU and task count, then RDS metrics and connections |
| Everything flat but alert fired | Metric artefact | Look for very low request volume |

## 3. Stop the bleeding

- A recent deploy is the first suspect. Revert the pull request and let the pipeline apply it, or
  point the service at the previous task definition revision.
- Tasks failing health checks: confirm the container port and health path match the target group.
- Saturated: raise `max_capacity` or `desired_count` through a pull request.
- Database: check connection count and storage before restarting anything.

## 4. Confirm recovery

- The 5-minute 5xx ratio is back under the budget line. The short window clears first and the
  composite alarm returns to OK.
- Note when it started, when it was detected, when it was mitigated and when it was fixed.

## 5. Afterwards

- Estimate how much error budget the incident used (minutes of failure over 43).
- Write a postmortem from the [template](POSTMORTEM-TEMPLATE.md) for any fast-burn page.
