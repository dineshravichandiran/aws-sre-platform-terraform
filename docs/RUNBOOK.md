# Runbook: first deploy, drills, destroy

Do this in one sitting so the stack exists for a few hours, not days. Budget about two hours.

## 0. What you need

- An AWS account you own, and an admin-capable login for the one-time bootstrap.
- AWS CLI v2 signed in (`aws sts get-caller-identity` works), Terraform 1.10 or newer, `gh` signed in.
- This repository pushed to GitHub as `dineshravichandiran/aws-sre-platform-terraform`
  (if you use another owner or name, pass it as `github_repository` in step 1).

## 1. Bootstrap (once, local state)

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # set budget_email
terraform init
terraform plan -out tfplan
terraform apply tfplan
terraform output
```

If the account already has a GitHub OIDC provider, set `create_oidc_provider = false` first: AWS
allows only one per account. The three outputs are used in the next step. Keep `bootstrap/terraform.tfstate`
safe; it is not committed.

## 2. Tell GitHub about the account (variables, not secrets)

```bash
gh variable set AWS_REGION         --body "ap-south-1"
gh variable set TF_STATE_BUCKET    --body "<state_bucket output>"
gh variable set AWS_PLAN_ROLE_ARN  --body "<plan_role_arn output>"
gh variable set AWS_APPLY_ROLE_ARN --body "<apply_role_arn output>"
```

These are identifiers, not credentials. Anyone can see them and still cannot assume the roles,
because the roles only trust tokens from this repository's pull requests and `dev` environment.

## 3. Create the protected environment

GitHub: Settings, Environments, New environment `dev`. Add yourself as a required reviewer. Every
apply and destroy now waits for your approval.

## 4. First deploy through the pipeline

1. Create a branch, change a default in `envs/dev/variables.tf` (for example set
   `allowed_ingress_cidrs` to `["YOUR.IP.ADDR.ESS/32"]` so only you can reach the demo), open a
   pull request. The pipeline does not read `terraform.tfvars`, so defaults are what it deploys.
   Your IP address then sits in a public repository's history, so use a private fork, or accept that
   and put the default back to `0.0.0.0/0` in a follow-up commit once you have destroyed the stack.
2. Confirm the `static` job passes and the `plan` job posts the plan as a comment.
   **Screenshot the plan comment.**
3. Merge. The `apply` job waits for approval. Approve it.
4. When it finishes, read the URL from the job output (`terraform output`).

If the plan or apply fails on permissions, read the `AccessDenied` action name, add that action to
the apply role in `bootstrap/main.tf`, re-run the bootstrap apply, and write down what you changed.
That is normal on a first run and is worth telling in an interview.

## 5. Check that it really works

```bash
URL=<url output>
curl -I "$URL"                                   # expect HTTP 200 from nginx
aws ecs describe-services --cluster sre-platform-dev --services sre-platform-dev \
  --query 'services[0].{running:runningCount,desired:desiredCount,status:status}'
aws logs tail /ecs/sre-platform-dev --since 10m
```

**Screenshot**: the 200 response, the ECS service with 2 running tasks, the load balancer target
group showing two healthy targets, the S3 bucket's versioning, the state file's lock behaviour.

## 6. Drills (each one is an interview story)

| Drill | How | What you should see |
|---|---|---|
| A task dies | `aws ecs stop-task --cluster sre-platform-dev --task <id>` | ECS starts a replacement; the load balancer keeps serving from the other task |
| Bad release | Set `container_image` to a tag that does not exist, merge, approve | The circuit breaker rolls back; the old tasks keep serving. Note the time it took |
| Drift | Change a security group rule by hand in the console, then open a pull request | The plan shows Terraform reverting your change. Write down what drift looks like in a plan |
| State lock | Start `terraform plan` locally and a second one in another terminal | The second waits or fails with a lock message instead of corrupting state |
| Load | `hey -z 2m -c 50 "$URL"` (or `ab`) | CPU rises, autoscaling adds tasks up to 4, then scales back in |

Record, for each drill, what you did, what happened and what surprised you. Put it in
`docs/evidence/drills.md`. Write only what actually happened.

## 7. Destroy the same day

GitHub: Actions, `terraform-destroy`, run it with `destroy-dev`, approve. Or locally:

```bash
cd envs/dev
terraform init -backend-config=backend.hcl
terraform destroy
```

Leave `bootstrap/` in place (it costs almost nothing) or remove it last:
empty the state bucket's versions first, then `terraform destroy` in `bootstrap/`.

## 8. Confirm nothing is left running

```bash
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-nat-gateways --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId'
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
aws ec2 describe-addresses --query 'Addresses[].PublicIp'
```

All four should be empty. Check Cost Explorer the next day, grouped by the `Project` tag.

## 9. Update the README

Only after steps 4 to 8 are done, change the three "not done yet" rows in the README's table to
"done" with the date, add your screenshots to `docs/evidence/`, and remove the "not yet applied"
status line. Until then the README must keep saying it has not been applied.

## Common first-run problems

| Symptom | Likely cause |
|---|---|
| `Error: Failed to get existing workspaces` or access denied on init | Wrong bucket name in `TF_STATE_BUCKET`, or the plan role is missing the state permissions |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Role trust does not match: wrong repository name, or the job is not in the `dev` environment. New GitHub repositories can also put immutable IDs in the token subject (`repo:owner@<id>/name@<id>:pull_request`); if the role trusts the plain `owner/name`, set `github_repository` in the bootstrap to the form shown in the token and re-apply the bootstrap |
| CloudShell: `no space left on device` | The AWS provider is about 770 MB per `.terraform` directory and CloudShell has 1 GB. Delete old `.terraform` directories and set `TF_PLUGIN_CACHE_DIR` |
| CloudShell: `terraform: command not found` | Terraform is not preinstalled. Put the binary in `~/bin` and add it to `PATH` each session |
| ECS tasks stop with `CannotPullContainerError` | No route out: check the NAT gateway and the private route tables |
| Targets stay unhealthy | Health check path or port does not match the container (`container_port`, `health_check_path`) |
| `OIDC provider already exists` | Set `create_oidc_provider = false` in the bootstrap |
