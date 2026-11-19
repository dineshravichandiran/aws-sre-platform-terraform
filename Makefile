# Everything here runs offline: no AWS account, no credentials, no cost.
DIRS_VALIDATE := modules/vpc modules/alb modules/ecs-service modules/rds modules/slo envs/dev bootstrap
DIRS_TEST     := modules/vpc modules/alb modules/ecs-service modules/rds modules/slo envs/dev

.PHONY: all fmt validate test scan
all: fmt validate test scan

fmt:
	terraform fmt -check -recursive

validate:
	@for d in $(DIRS_VALIDATE); do \
	  echo "== validate $$d"; \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null && terraform -chdir=$$d validate || exit 1; \
	done

test:
	@for d in $(DIRS_TEST); do \
	  echo "== test $$d"; \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null && terraform -chdir=$$d test || exit 1; \
	done

scan:
	checkov -d . --framework terraform --skip-path '.terraform' --compact --quiet
