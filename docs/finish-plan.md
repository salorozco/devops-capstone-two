# Proposed Finish Plan

This is the proposed plan for finishing `devops-capstone-two`.
It now reflects the Jenkins bootstrap cleanup completed after the original plan.

## Goal

Finish the Jenkins pipeline project so it can show a full DevOps flow:

```text
Terraform
  -> EC2 Jenkins manager
  -> EC2 Jenkins worker
  -> EC2 app server
  -> Ansible configures all servers
  -> Jenkins runs a job on the worker
  -> Jenkins deploys an app to the app server
```

## Change Order

### 1. Repo hygiene and Terraform fixes

Files likely touched:

- `infra/terraform/versions.tf`
- `infra/terraform/main.tf`
- `infra/terraform/variables.tf`
- `infra/terraform/inventory.tpl`
- `.gitignore`
- maybe `infra/ansible/inventory/.gitkeep`

Planned changes:

1. Add the `hashicorp/local` provider requirement because `main.tf` uses `local_file`.
2. Format Terraform files with `terraform fmt`.
3. Decide what to do with unused variables:
   - `subnet_ids`
   - `security_group_id`
4. Add app server private IP to the generated inventory if Jenkins deploys over the private network.
5. Ignore generated `infra/ansible/inventory/hosts.ini`, but keep the inventory directory in git with `.gitkeep`.
6. Consider a security group self-rule for the app port if worker/app communication needs private traffic.

Reason:

- Terraform should validate cleanly and generate the exact inventory Ansible needs.

### 2. Fix Jenkins JCasC structure

Status: completed.

Files touched:

- `infra/ansible/templates/jenkins/jenkins.yaml.j2`

Removed files:

- `infra/ansible/files/jenkins/jenkins.yaml`

Completed changes:

1. Merge the duplicate top-level `jenkins:` sections into one valid block.
2. Keep the admin user, authorization strategy, and node config together under the active `jenkins:` block.
3. Keep credentials and jobs as separate top-level JCasC sections.
4. Remove the old static `files/jenkins/jenkins.yaml` file.
5. Set the Jenkins worker labels consistently.

Recommended label:

```text
linux docker worker
```

Reason:

- The test job expects label `worker`.
- The worker is also a Linux Docker-capable node.

### 3. Harden Jenkins secrets handling

Status: completed for Jenkins manager bootstrap.

Files touched:

- `.env.example`
- `.gitignore`
- `scripts/deploy_infra.sh`
- `infra/ansible/site.yml`
- `infra/ansible/templates/jenkins/jenkins.yaml.j2`

Completed changes:

1. Stop hardcoding the Jenkins admin password directly in `site.yml`.
2. Read it from `JENKINS_ADMIN_PASSWORD`.
3. Fail with a clear message if no password is supplied.
4. Write rendered JCasC with stricter permissions because it contains a private key.
5. Load repo-root `.env` from `scripts/deploy_infra.sh` if present.
6. Keep real `.env` ignored and commit only `.env.example`.
7. Suppress Ansible logging for sensitive private-key read/render tasks.

Recommended rendered JCasC mode:

```text
0600
```

Reason:

- The current rendered JCasC includes the controller private key.

### 4. Wire the Jenkins worker test job

Status: completed as an inline JCasC job.

Files touched:

- `infra/ansible/templates/jenkins/jenkins.yaml.j2`
- `infra/ansible/files/jenkins/plugins.txt`

Removed files:

- `infra/ansible/files/jenkins/seed.groovy`

Completed changes:

1. Define `test-agent` directly in the active JCasC template.
2. Remove standalone `seed.groovy` to keep one source of truth.
3. Confirm the job label matches the worker label.
4. Keep the test job simple:
   - show hostname
   - show Java
   - show Docker
   - run `docker ps`

Reason:

- Before building a deploy job, we should prove Jenkins can use the worker.

### 5. Configure the app server

Files likely touched:

- `infra/ansible/site.yml`
- `infra/terraform/inventory.tpl`
- maybe `infra/terraform/main.tf`

Planned changes:

1. Add an Ansible play for `app_server`.
2. Install Docker.
3. Enable and start Docker.
4. Add `ubuntu` to the Docker group.
5. Create an app directory, for example:

```text
/opt/capstone-app
```

6. Authorize the Jenkins controller public key on the app server.

Reason:

- The app server currently exists but has no deploy target setup.

### 6. Add a real app deploy pipeline

Files likely touched:

- `Jenkinsfile`
- app files, if missing
- `infra/ansible/templates/jenkins/jenkins.yaml.j2`
- `infra/ansible/files/jenkins/plugins.txt`

Planned changes:

1. Add or confirm a small app that can be containerized.
2. Add a Dockerfile if one does not exist.
3. Add a Jenkins pipeline job.
4. Run the build on the Jenkins worker.
5. Deploy to the app server over SSH.
6. Start or restart the Docker container on the app server.
7. Expose the app on `var.app_port`, currently `8081`.

Potential plugin addition:

```text
ssh-agent
```

Reason:

- Pipeline deploy steps usually need a Jenkins SSH credential inside the build.

### 7. README and runbook

Files likely touched:

- `README.md`
- `docs/current-flow.md`
- maybe another runbook under `docs/`

Planned changes:

1. Explain the architecture.
2. List required parameters.
3. Show local prerequisites.
4. Show safe validation commands.
5. Show deploy commands for the user to run manually.
6. Show teardown commands for avoiding AWS charges.
7. Add screenshot checklist for the portfolio.

Reason:

- This project should be understandable as a portfolio project and as a lab runbook.

## Validation Plan

Local validation only:

1. `terraform fmt -check -recursive`
2. `terraform validate`
3. `ansible-playbook --syntax-check`
4. `git diff --check`

Manual AWS validation after the user runs deploy:

1. Confirm EC2 instances exist.
2. Confirm security group rules.
3. Confirm generated inventory.
4. Confirm Ansible completes.
5. Open Jenkins UI.
6. Confirm worker node is online.
7. Run test job.
8. Run deploy job.
9. Open app URL on the app server.

## Things Not To Run Automatically

Do not run these unless explicitly requested:

- `terraform apply`
- `terraform destroy`
- `scripts/deploy_infra.sh`
- Any Jenkins deploy job against live AWS infrastructure
- Any AWS cleanup command

## Suggested Next Step

Start with the next infrastructure/app-server checkpoint:

1. Fix Terraform hygiene and provider declarations.
2. Add app server private IP to the generated inventory.
3. Configure the app server with Docker and a deploy directory.
4. Authorize Jenkins SSH access to the app server.

That gives a clean checkpoint before adding the real app deploy pipeline.
