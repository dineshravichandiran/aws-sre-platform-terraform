# Service level objectives

Defined for the web service behind the load balancer. The Terraform for the alerts is in
[`modules/slo`](../../modules/slo).

## Indicators (what is measured)

| SLI | Definition | Source |
|---|---|---|
| Availability | 1 minus (target 5xx + load balancer 5xx) divided by requests | ALB metrics `HTTPCode_Target_5XX_Count`, `HTTPCode_ELB_5XX_Count`, `RequestCount` |
| Latency | p99 of `TargetResponseTime` | ALB metric |

Why the load balancer and not the app: it sees every request, including the ones that never reach
a healthy task (a 503 when no target is healthy counts as a failure, which it is for the user).

## Objectives

| Objective | Target | Window |
|---|---|---|
| Availability | 99.9% | rolling 30 days |
| Latency | p99 under 1 second | 5 minutes sustained |

99.9% over 30 days leaves an **error budget of 0.1%**: about **43 minutes** of total outage, or
the equivalent in failed requests. Change the target with `slo_target`; the thresholds follow it.

## Alerts: multiwindow, multi-burn-rate

A burn rate of 1 means the budget would be used up in exactly 30 days. Higher burn rates use it up
faster. Two rules, each needing a long window and a short window to agree:

| Rule | Burn rate | Windows | Budget used when it fires | Action |
|---|---|---|---|---|
| Fast burn | 14.4x | 1 hour and 5 minutes | about 2% in one hour | Page now |
| Slow burn | 6x | 6 hours and 30 minutes | about 5% in six hours | Page, less urgent |

The arithmetic: `14.4 x 1h / 720h = 2%` and `6 x 6h / 720h = 5%`. A threshold of `14.4 x 0.001 = 1.44%`
of requests failing is what the fast rule watches for.

Why two windows per rule: the long window shows the problem is large enough to matter, the short
window shows it is still happening. Without the short window an alert keeps firing for an hour after
the problem is fixed. Without the long window a brief spike pages someone for nothing.

No traffic is treated as no errors, not as an outage, so an idle demo does not page.

## Error budget policy

| Budget left | What changes |
|---|---|
| More than 50% | Ship normally |
| 10% to 50% | Reliability work is scheduled alongside features; risky changes need a rollback plan |
| Under 10% | Feature releases pause; only fixes and reliability work ship until the window recovers |
| Spent | Freeze, write a postmortem, agree the plan to recover before shipping again |

## Known limits

- The denominator is `RequestCount`; requests the load balancer rejects before routing may not be
  counted, so the ratio is approximate during a total outage. The alert still fires, because the
  load balancer 5xx count rises.
- CloudWatch metric math alarms evaluate on fixed periods, not a sliding window. The Google SRE
  workbook alerts assume Prometheus-style recording rules; this is the CloudWatch approximation.
- The objectives are a starting point for a demo service. Real ones come from what users need and
  what the service has actually achieved.
- Nothing here has been run against live traffic yet. Verifying it needs the runbook's load drill.
