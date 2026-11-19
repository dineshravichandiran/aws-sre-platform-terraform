# Remote state lives in S3 with native locking. The bucket name differs per AWS
# account, so it is not written here. Pass it at init time:
#   terraform init -backend-config=backend.hcl
# See backend.hcl.example and docs/RUNBOOK.md.
terraform {
  backend "s3" {}
}
