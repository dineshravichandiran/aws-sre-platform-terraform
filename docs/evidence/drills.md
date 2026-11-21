# Drills: what I did and what happened

Run on 20 November 2026 IST (19 November UTC) in `ap-south-1`, against a real deployment of
`envs/dev`. Times below are UTC as logged in CloudShell (IST is +5:30). Every number is copied from
my own raw log (`drills.log`), not rounded up or estimated.

## Deployment

- Deployed through the pipeline: pull request #7 (narrow `allowed_ingress_cidrs` to one `/32`), plan
  comment posted on the pull request, merge, approval on the `dev` environment, then apply.
- Apply run #14: **56 resources added**, apply job 9m 59s, whole run 14m 59s.
- The load balancer served the default nginx page; the ECS service had 2 running tasks and the target
  group had 2 healthy targets.

Screenshots in this folder:

| File | Shows |
|---|---|
| `01-nginx-live.png` | nginx welcome page served through the load balancer |
| `02-ecs-2-running.png` | ECS service Active, 2 running, deployment Success |
| `03-targets-healthy.png` | Target group: 2 healthy, 0 unhealthy |
| `04-apply-success-56-resources.png` | Apply run #14 finished green (the 56 count is from the apply log) |
| `05-plan-comment-pr7.png` | The plan posted on pull request #7 |

## Drill 1: a task dies

- **Did:** `aws ecs stop-task` on one of the two running tasks at 20:50:26.
- **Saw:** the service dropped to 1 running, the stopped task's target went to `draining`, a replacement
  was started (1 running, 1 pending at 20:51:02), and at 20:51:25 the service was back to 2 running with
  both targets `healthy`.
- **Time to recover:** about 59 seconds from the stop to 2 running and 2 healthy.
- **Not measured:** client-side errors during the 59 seconds. I watched task and target states, not a
  stream of requests, so I can say one target stayed registered and healthy, not that no request failed.

## Drill 2: drift

- **Did:** at 20:55:53 I added a tag (`drift=manual-console-edit`) to the load balancer's security group
  outside Terraform, then ran `terraform plan`.
- **Saw:** the plan said `Plan: 0 to add, 1 to change, 0 to destroy`, an in-place update on
  `module.alb.aws_security_group.this` that removes the extra tag. That is what drift looks like in a
  plan: a small in-place change nobody wrote in code.
- I removed the tag by hand at 20:56:43 instead of applying, and the re-plan returned
  `No changes. Your infrastructure matches the configuration.`

## Drill 3: state lock

- **Did:** started one `terraform plan`, and while it was running started a second one at 20:57:26.
- **Saw:** the second failed with `Error acquiring the state lock` and `StatusCode: 412`, showing the lock
  holder, operation (`OperationTypePlan`) and creation time. The first plan finished at 20:57:36 with
  `No changes`.
- State is in S3 with the native lock file (`use_lockfile`), no DynamoDB table. The 412 is the failed
  conditional write on the lock object.

## Drill 4: load

- **Did:** `ab -n 20000 -c 50` against the load balancer, run from my laptop.
- **Result (ApacheBench):** 20000 requests in 41.35 s, **0 failed**, 483.68 requests/s. Time per
  request 103 ms mean at concurrency 50. Percentiles: 50% 70 ms, 95% 109 ms, 99% 1078 ms, longest 7035 ms.
- **CloudWatch for the same minute (21:33):** load balancer `RequestCount` 20000; ECS CPU maximum
  **3.53%** (baseline between 0.02% and 0.4%); no `HTTPCode_ELB_5XX_Count` datapoints; target response
  time maximum about 6 ms.
- **Autoscaling did not trigger.** The policy is target tracking at 60% average CPU
  (`sre-platform-dev-cpu-target`), CPU peaked at 3.5%, `describe-scaling-activities` returned nothing,
  and the service stayed at 2 tasks. Serving a static nginx page is too cheap to move CPU, so this drill
  shows the service handling the load, not scale-out. Testing scale-out would need a CPU-heavy endpoint
  or a lower target.
- **Tail latency:** the 7-second worst case was in `Connect` (max 7008 ms) while `Processing` max was
  227 ms and the target response time was milliseconds. That points at connection setup between my laptop
  and the load balancer, not the application. I did not dig further, so treat that as a likely cause,
  not a proven one.

## Drill 5: bad release and the circuit breaker

- **Did:** pull request #8 changed `container_image` to a tag that does not exist (`:no-such-tag`), merged,
  approved the apply.
- **Saw:** the new deployment started at about 21:05:47 and kept starting tasks that could not pull the
  image, while the old deployment kept its 2 running tasks. The ECS circuit breaker rolled back at
  **21:20:39**, about 15 minutes after the deployment began.
- **What surprised me:** I expected a rollback in a couple of minutes because I assumed three failed
  tasks would trip it. The circuit breaker's minimum failure threshold is 10 failed tasks, which fits
  the roughly 15 minutes I saw. Worth stating in an interview as a limit, not a hidden detail.
- **Fixing Terraform:** the rollback fixed the running service, but the code still said `:no-such-tag`, so
  I reverted the change with pull request #9 (merged 21:23:20), approved the apply, and the revert
  deployment went from in-progress at 21:27:52 to completed at 21:30:56, about 3 minutes after it started.
  Running state and code were back in agreement.
- **Not measured:** request errors during the bad deployment. The old tasks stayed running the whole
  time, but I did not send traffic through it.

## Problems I hit (and fixed)

- **OIDC trust failed with `Not authorized to perform sts:AssumeRoleWithWebIdentity`.** GitHub now puts
  the immutable repository and owner IDs into the token's subject for new repositories, for example
  `repo:owner@<id>/name@<id>:pull_request`. The trust policies expected the plain `owner/name` form. I
  set the bootstrap variable `github_repository` to the immutable form and re-applied the bootstrap
  (0 to add, 2 to change, just the two role trust policies). The repository code is unchanged.
- **`terraform fmt` failed on the first pull request** because the web editor left a stray leading space.
- **CloudShell ran out of disk** (1 GB limit; the AWS provider download is about 770 MB per directory).
  Removed the `.terraform` directories and used a shared plugin cache.
- **Terraform is not preinstalled in CloudShell.** I put the binary in `~/bin` for each session.

## Teardown

- Ran `terraform-destroy` (`destroy-dev`), approved on the `dev` environment: run #1 succeeded, job 5m 59s.
- Checked at 21:57:45 UTC that nothing was left: no load balancers, no NAT gateways, no RDS instances, no
  Elastic IPs, no ECS clusters, and no VPC tagged `Project=sre-platform`.
- The stack existed for under two hours (first apply to destroy).

## Cost (read from Cost Explorer on 2026-11-21)

- Account total for 2026-11-19 (UTC), the day the stack ran: **US$0.31**, flagged estimated by AWS. By service:
  EC2-Other (NAT gateway and data) 0.13, load balancing 0.07, RDS 0.03, ECS 0.03, VPC (public IPv4) 0.03,
  EC2 compute 0.02.
- Grouping by the `Project` tag returned a single blank-value group, so the `Project` tag is not an active
  cost allocation tag in this account. The figure above is therefore the whole account's cost for that day,
  not a tag-filtered one. Everything on that day is a service this stack uses, but I did not separate out any
  other usage.
- Not part of this number: 2026-11-20 shows US$2.95 (mostly VPC charges), which comes from other labs run
  that day, not from this stack.
