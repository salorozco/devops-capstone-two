# Finish Plan

Last updated: 2026-05-31

The core lab is now functional:

```text
Terraform
  -> Ansible
  -> Jenkins as Code
  -> Jenkins worker build
  -> Docker Hub push
  -> app server pull/restart
  -> smoke test
```

## Completed

1. Terraform creates the AWS instances and security group.
2. Terraform creates/manages the Docker Hub repository.
3. Terraform generates the Ansible inventory.
4. Ansible configures the Jenkins manager, Jenkins worker, and app server.
5. Jenkins is bootstrapped through JCasC.
6. Jenkins credentials are created through JCasC.
7. Jenkins worker node is configured.
8. `test-agent` verifies the worker.
9. `deploy-capstone-app` runs from the root `Jenkinsfile`.
10. The pipeline builds and pushes Docker images to Docker Hub.
11. The app server pulls and runs the exact Git SHA image tag.
12. The pipeline smoke-tests the running container.
13. Docker credentials are cleaned up with temporary Docker config directories.
14. Pipeline Graph View is installed for a better Jenkins UI.
15. Generated Ansible inventory is ignored by Git.

## Remaining Production-style Improvements

### 1. GitHub webhook

Current state:

```text
Jenkins polls GitHub every couple minutes.
```

Future state:

```text
GitHub push to main
  -> webhook
  -> Jenkins pipeline starts immediately
```

This should wait until Jenkins has a stable HTTPS URL.

### 2. Remote Terraform state

Current state:

```text
Terraform state is local.
```

Future state:

```text
S3 backend for state
DynamoDB table for locking
restricted IAM access
bucket encryption and versioning
```

This is intentionally paused for now.

### 3. Jenkins access hardening

Current lab state:

```text
Jenkins is reachable on public port 8080 from my_ip_cidr.
```

Future options:

- HTTPS reverse proxy or ALB.
- DNS name.
- VPN/private access.
- SSO or stronger auth model.

### 4. Token separation

Current state:

```text
Docker Hub credentials are supplied from repo-root .env.
```

Future state:

- Terraform token for Docker Hub repository management.
- Jenkins token for image push/pull.
- Narrower permissions for each token.

### 5. Terraform cleanup

Potential follow-ups:

- Review unused variables.
- Add explicit `hashicorp/local` provider requirement if desired.
- Move generated inventory ownership fully into Terraform/runbook.
- Add backend configuration when remote state is ready.

## Normal Runbook

Deploy infrastructure and configure Jenkins:

```bash
./scripts/deploy_infra.sh
```

Validate locally:

```bash
cd infra/terraform
terraform validate
```

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.ini site.yml --syntax-check
```

Tear down AWS resources when done with a lab session. Preserve Docker Hub repo unless intentionally cleaning the registry too.
