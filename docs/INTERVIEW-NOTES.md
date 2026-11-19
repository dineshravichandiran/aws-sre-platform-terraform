# Interview notes: Terraform on AWS

Answers are about what is in this repository. Where something has not been done yet, the answer
says so. Say the same thing in the room.

## The one-minute version

"I built a small AWS platform as Terraform modules: a VPC across two zones, an ALB, an ECS Fargate
service in private subnets, a private PostgreSQL database, and SLO burn-rate alerts on the load balancer. State is in S3 with locking.
GitHub Actions plans on every pull request with a read-only role and applies after a reviewer
approves, signing in with OIDC so there are no stored AWS keys. checkov and tflint run on every
push, and mocked-provider tests check the wiring. I deployed it to a real account through the
pipeline (56 resources), ran five drills, and destroyed it the same day. The write-up with my own
numbers is in `docs/evidence/drills.md`."

## State

**What is Terraform state and why remote?** State maps the resources in code to the real objects in
AWS. Locally it lives in one laptop's file. In S3 the team shares one copy, it is versioned so a bad
write can be rolled back, and encrypted because state can hold sensitive values.

**How is locking done here?** S3 native locking (`use_lockfile = true`, Terraform 1.10 and newer):
a `.tflock` object is created next to the state file for the duration of a run. A second plan or
apply waits (`-lock-timeout`) or fails instead of writing at the same time. Older setups use a
DynamoDB table for the same job. I chose native locking to have one fewer resource.

**Why is the state bucket not created by the same code?** Chicken and egg: the backend must exist
before `terraform init` can use it. So `bootstrap/` runs once with local state and creates the
bucket, the roles and the budget. Everything else uses the remote backend.

**What if state and reality differ?** That is drift. `terraform plan` shows it. I decide whether
the code or the real resource is right: apply to revert, or change the code to match. For a
resource created by hand, `terraform import` adopts it into state.

## Modules

**Why modules?** One place defines "a VPC" or "an ECS service", with a small set of inputs and
outputs, so every environment builds it the same way. Each module here has validation on its
inputs (for example at least two zones) and its own tests.

**How did you decide what goes in a module?** A module is a unit with one job and a clear
interface: the VPC module outputs subnet IDs, the ALB module outputs a target group and a security
group, and the ECS module takes those as inputs. The environment only wires them together.

**A bug the tests found.** The first version of the database module used `for_each` over security
group IDs. Those IDs are only known after apply, so a real plan would fail with "Invalid for_each
argument". The environment-level test caught it. The fix was `count`, because the number of
clients is known at plan time even when their IDs are not. This is the standard unknown-at-plan
problem.

## Plan, apply, pipeline

**What does the pipeline do?** Pull request: format, validate, lint, security scan, tests, then a
plan posted as a comment. Merge to main: a plan, then apply of that saved plan file, only after
approval in the `dev` environment.

**Why apply the saved plan?** So that what was reviewed is what runs. Applying fresh could pick up
a change that landed between the plan and the apply.

**Why OIDC instead of access keys?** Keys are long-lived and leak. With OIDC the job asks GitHub
for a short-lived token, and AWS exchanges it for temporary credentials only if the token's
subject matches the role's trust policy: pull requests of this repo for the plan role, the `dev`
environment for the apply role. Nothing to rotate or steal from the repository.

**Why two roles?** Least privilege by stage. A pull request can only read. Only an approved run
on the protected environment can change anything.

**What is weak about the apply role?** It uses PowerUserAccess plus a narrow IAM statement scoped to
`sre-platform-*` roles. That is broader than ideal. The next step is to build the policy from the
exact actions a real plan and apply need.

## Security and cost

**What is secured and how?** Tasks and the database are in private subnets. The database accepts
5432 only from the task security group. The task security group accepts the app port only from the
load balancer. The RDS password is generated and stored by Secrets Manager and never appears in
code or plan output. Buckets block public access and refuse non-TLS requests.

**What did the scanner say?** 259 checks pass, none fail. 20 are skipped, and each skip sits next to
the resource with the reason, for example Multi-AZ is off to halve the demo cost. I did not turn
checks off to get a green result; where a finding was fair I fixed it (longer log retention,
pinned zones, a narrower IAM statement).

**How do you control cost?** Tags on everything through `default_tags`, a budget alert at 80%
actual and 100% forecast, one shared NAT gateway, small instance sizes, and destroying the same
day. The NAT gateway and the load balancer are the biggest fixed costs.

## SLOs and alerting

**How do you define an SLO?** Start from what the user feels, pick an indicator that measures it,
then set a target the service can really hold. Here: availability is the share of requests that
did not fail on the server side (target and load balancer 5xx over requests), objective 99.9% over
30 days. That leaves an error budget of 0.1%, about 43 minutes.

**What is an error budget for?** It turns reliability into a number to spend. While there is
budget, ship. As it runs low, slow down risky change. It ends the argument between "ship faster"
and "make it more reliable" because both are measured against the same figure.

**Why burn-rate alerts instead of "error rate above 1%"?** A fixed threshold either pages on short
spikes that do not matter or misses a slow leak that quietly eats the month. Burn rate asks how
fast the budget is being used. 14.4x for an hour means 2% of the month's budget is gone in one
hour, so page now. 6x for six hours means 5% is gone, so page less urgently.

**Why two windows on each rule?** The long window proves the problem is big enough to matter. The
short window proves it is still happening, so the alert clears quickly once it is fixed.

**What are the limits of what you built?** It is the CloudWatch approximation: fixed evaluation
periods, not sliding windows. The thresholds are not tuned on real traffic, because the stack has
not served any yet. A real service would also have per-endpoint objectives.

## Design questions

**Why ECS and not EKS?** For one stateless service, Fargate means no nodes to patch and much less to
operate. I have a separate EKS project for the Kubernetes side. I would choose EKS when there are
many services, a need for Kubernetes tooling, or a platform team to run it.

**Workspaces or separate directories for environments?** Directories (`envs/dev`, later `envs/prod`)
with a shared module set. Each has its own state key and its own review, and a mistake in one
cannot silently touch the other. Workspaces share one backend config and make it easy to forget
which environment you are in.

**What breaks if the NAT gateway's zone fails?** Private subnets lose outbound access, so new tasks
cannot pull images. Running tasks keep serving inbound traffic through the load balancer.
`single_nat_gateway = false` builds one per zone to remove that risk at roughly double the NAT cost.

**What happens on a bad release?** The ECS deployment circuit breaker marks the deployment failed
and rolls back to the last good task definition, while the old tasks keep serving. The runbook has
a drill for it. I ran it: a bad image tag rolled back by itself after about 15 minutes, because the
breaker waits for 10 failed tasks, not 3. I then reverted the code with a pull request so state and
code agreed again (about 3 minutes to a healthy deployment).

## Stories from the real run (all in `docs/evidence/drills.md`)

- **Apply error:** OIDC sign-in failed with `Not authorized to perform sts:AssumeRoleWithWebIdentity`.
  GitHub now puts immutable owner and repo IDs in the token subject for new repositories, so the trust
  policy did not match. I changed the bootstrap variable, re-applied (2 role trust policies changed),
  code untouched.
- **A task dies:** stopped one of two tasks; back to 2 running and healthy in about 59 seconds. I did not
  measure client errors during that time.
- **Drift:** added a tag by hand; the plan showed `0 to add, 1 to change, 0 to destroy`; after I removed
  it, `No changes`.
- **State lock:** second plan failed with `Error acquiring the state lock`, `StatusCode: 412` (S3 native
  lock, no DynamoDB).
- **Load:** 20,000 requests, 50 concurrent, 0 failed, about 483 requests/s. Autoscaling did **not**
  trigger (CPU peaked at 3.5% against a 60% target), so I do not claim scale-out. Testing it needs a
  CPU-heavy endpoint.
- **Cost:** not read from Cost Explorer yet. Do not quote a figure until it is.

## Questions to expect that this repo cannot answer yet

- Terraform at team scale: module registries, versioning modules, policy as code (OPA or Sentinel).
  Say you know where they fit and that you have not run them.
