# Interview notes: Terraform on AWS

Answers are about what is in this repository. Where something has not been done yet, the answer
says so. Say the same thing in the room.

## The one-minute version

"I built a small AWS platform as Terraform modules: a VPC across two zones, an ALB, an ECS Fargate
service in private subnets, and a private PostgreSQL database. State is in S3 with locking.
GitHub Actions plans on every pull request with a read-only role and applies after a reviewer
approves, signing in with OIDC so there are no stored AWS keys. checkov and tflint run on every
push, and mocked-provider tests check the wiring. [Once applied: I deployed it, ran failure
drills, and destroyed it the same day.] [Until then: it is validated and tested but I have not
applied it to a live account yet.]"

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

**What did the scanner say?** 254 checks pass, none fail. 19 are skipped, and each skip sits next to
the resource with the reason, for example Multi-AZ is off to halve the demo cost. I did not turn
checks off to get a green result; where a finding was fair I fixed it (longer log retention,
pinned zones, a narrower IAM statement).

**How do you control cost?** Tags on everything through `default_tags`, a budget alert at 80%
actual and 100% forecast, one shared NAT gateway, small instance sizes, and destroying the same
day. The NAT gateway and the load balancer are the biggest fixed costs.

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
a drill for it.

## Questions to expect that this repo cannot answer yet

- Running a real apply, hitting an error, and fixing it. Do the runbook before the interview, then
  tell that story with real details.
- Terraform at team scale: module registries, versioning modules, policy as code (OPA or Sentinel).
  Say you know where they fit and that you have not run them.
