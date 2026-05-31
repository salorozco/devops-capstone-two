# Finish Plan

Last updated: 2026-05-31

The lab now uses Terraform stacks and modules.

## Completed

1. Terraform split into reusable modules:
   - `dockerhub_repository`
   - `ec2_instance`
   - `security_group`
2. Terraform split into lifecycle stacks:
   - `registry`
   - `ci`
   - `app`
3. Docker Hub repository separated from AWS lab resources.
4. CI platform separated from app runtime infrastructure.
5. App stack can be destroyed without deleting Jenkins or Docker Hub.
6. Full deploy wrapper still exists through `scripts/deploy_infra.sh`.
7. Ansible moved from generated `hosts.ini` to AWS dynamic inventory.
8. Jenkins restart handlers added for JCasC/plugin/systemd changes.
9. Jenkins pipeline builds, pushes, deploys, and smoke-tests the app.

## Remaining Production-style Improvements

### 1. Remote Terraform state

Current state:

```text
Each stack uses local state.
```

Future state:

```text
S3 backend per stack
DynamoDB lock table
state encryption
restricted IAM access
```

This is intentionally paused for now.

### 2. Stack output sharing

Current state:

```text
scripts/deploy_infra.sh passes ci_security_group_id from CI stack to app stack.
```

Future state with remote state:

```hcl
data "terraform_remote_state" "ci" {}
```

That should wait until remote state is introduced.

### 3. GitHub webhook

Current state:

```text
Jenkins polls GitHub.
```

Future state:

```text
GitHub push to main
  -> webhook
  -> Jenkins pipeline starts immediately
```

This should wait until Jenkins has a stable HTTPS endpoint.

### 4. Jenkins access hardening

Future options:

- HTTPS reverse proxy or ALB.
- DNS name.
- Private/VPN access.
- Stronger auth/SSO.

### 5. Secret separation

Current state:

```text
Docker Hub token comes from .env and is used for Terraform and Jenkins.
```

Future state:

- Terraform Docker Hub token for repo management.
- Jenkins Docker Hub token for image push/pull.
- Narrower permissions for each token.

### 6. Possible Ansible role split

Current state:

```text
infra/ansible/site.yml is still mostly monolithic.
```

Future structure:

```text
roles/common
roles/docker
roles/jenkins_worker
roles/app_server
roles/jenkins_controller
```

This is a good next cleanup after stack behavior is validated.

## Runbook

Full deploy:

```bash
./scripts/deploy_infra.sh
```

Destroy app only:

```bash
./scripts/destroy_app.sh
```

Destroy CI only:

```bash
./scripts/destroy_ci.sh
```

Destroy AWS lab resources but keep Docker Hub:

```bash
./scripts/destroy_all_aws.sh
```

Registry stack is intentionally excluded from AWS teardown.
