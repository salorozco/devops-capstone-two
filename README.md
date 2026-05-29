# DevOps Capstone Two

This repo is an AWS-based Jenkins CI/CD lab. It uses Terraform to create infrastructure, Ansible to configure servers, and Jenkins Configuration as Code to bootstrap a Jenkins controller with a worker node.

The current checkpoint proves the infrastructure and Jenkins worker path first. The app server is created, but the real application deployment pipeline is still the next phase.

## Architecture

```text
Local machine
  |
  | ./scripts/deploy_infra.sh
  v
Terraform
  |
  | creates AWS resources
  v
EC2 Jenkins manager
EC2 Jenkins worker
EC2 app server
  |
  | generated Ansible inventory
  v
Ansible
  |
  | installs/configures Jenkins and worker dependencies
  v
Jenkins manager
  |
  | SSH agent connection
  v
Jenkins worker
```

## Current Flow

1. `scripts/deploy_infra.sh` loads repo-root `.env` if present.
2. The script requires `JENKINS_ADMIN_PASSWORD`.
3. Terraform creates:
   - Jenkins manager EC2 instance
   - Jenkins worker EC2 instance
   - App server EC2 instance
   - Security group rules
   - Generated Ansible inventory
4. Ansible configures all instances with baseline package updates.
5. Ansible configures the Jenkins worker with Java, Docker, and a Jenkins workspace.
6. Ansible installs Jenkins on the manager.
7. Jenkins Configuration as Code creates:
   - local `admin` user
   - SSH credential for the worker
   - permanent worker node named `jenkins-worker-1`
   - test job named `test-agent`
8. Jenkins starts on port `8080`.

## Current Checkpoint

After running the deploy script, Jenkins should be available at:

```text
http://<JENKINS_MANAGER_PUBLIC_IP>:8080
```

Login:

```text
user: admin
password: value from JENKINS_ADMIN_PASSWORD
```

The expected validation job is:

```text
test-agent
```

That job verifies the worker can run shell commands and access Java and Docker.

## Required Local Files

Create a repo-root `.env` file:

```bash
JENKINS_ADMIN_PASSWORD='your-password-here'
```

Do not commit `.env`. It is ignored by git. Use `.env.example` as the safe template.

## Run

From the repo root:

```bash
./scripts/deploy_infra.sh
```

Important: this runs `terraform apply -auto-approve`, so it can create or update AWS resources.

## What Is Not Finished Yet

The app server is created, but the app deploy flow is not complete yet.

Remaining work:

1. Configure the app server with Docker and a deploy directory.
2. Authorize Jenkins SSH access to the app server.
3. Add a small deployable app.
4. Add a `Jenkinsfile`.
5. Create a Jenkins deploy pipeline.
6. Expose the app on the configured app port, currently `8081`.

## Safe Validation Commands

```bash
cd infra/terraform
terraform validate
terraform plan
```

```bash
cd infra/ansible
JENKINS_ADMIN_PASSWORD=test-password ansible-playbook --syntax-check site.yml
```

## Docs

More detail:

- `docs/current-flow.md`
- `docs/finish-plan.md`
