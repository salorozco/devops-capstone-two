# Current Infrastructure Flow

Last updated: 2026-05-31

This project now has a full Terraform, Ansible, Jenkins, Docker Hub, and app-server deployment flow.

## High-level Flow

```text
scripts/deploy_infra.sh
  -> Terraform
  -> AWS EC2 resources
  -> Docker Hub repository
  -> generated Ansible inventory
  -> Ansible
  -> Jenkins manager + worker + app server
  -> Jenkins deploy pipeline
  -> Docker Hub image
  -> app server container
  -> smoke test
```

## Deploy Script

File: `scripts/deploy_infra.sh`

The script:

1. Loads repo-root `.env` if present.
2. Requires Jenkins, GitHub, and Docker Hub environment variables.
3. Exports Docker Hub variables for the Docker Terraform provider.
4. Runs `terraform init -upgrade`.
5. Runs `terraform apply -auto-approve`.
6. Verifies `infra/ansible/inventory/hosts.ini` was generated.
7. Waits for SSH with Ansible ping.
8. Runs `ansible-playbook -i inventory/hosts.ini site.yml`.

## Terraform

Main files:

- `infra/terraform/main.tf`
- `infra/terraform/variables.tf`
- `infra/terraform/outputs.tf`
- `infra/terraform/inventory.tpl`
- `infra/terraform/versions.tf`

Terraform manages:

- AWS provider in `us-east-1` by default.
- Docker provider for Docker Hub.
- Docker Hub repository:

```text
docker.io/<dockerhub_namespace>/<dockerhub_repository_name>
```

- Security group `capstone-sg`.
- Jenkins manager EC2.
- Jenkins worker EC2.
- App server EC2.
- Generated Ansible inventory.

Security group rules:

- SSH `22` from `var.my_ip_cidr`.
- Jenkins `8080` from `var.my_ip_cidr`.
- App `var.app_port`, default `8081`, from `var.my_ip_cidr`.
- SSH between instances in the same security group.
- All outbound traffic.

## Generated Inventory

Template:

```text
infra/terraform/inventory.tpl
```

Generated file:

```text
infra/ansible/inventory/hosts.ini
```

Groups:

- `jenkins_manager`
- `jenkins_worker`
- `app_server`

Host vars:

- `jenkins_private_ip`
- `app_private_ip`

The generated inventory is ignored by Git and recreated by Terraform.

## Ansible

Main file:

```text
infra/ansible/site.yml
```

Ansible configures:

- Baseline apt cache updates on all hosts.
- Jenkins worker with Java 21, Docker, and workspace directory.
- App server with Docker, curl, Docker group access, and `/opt/capstone-app`.
- Jenkins manager with Java 21, Jenkins, plugins, JCasC, credentials, node config, and jobs.

Jenkins controller SSH key:

- Generated on the Jenkins manager.
- Added to the Jenkins worker.
- Added to the app server.
- Embedded into Jenkins credential `agent-ssh`.

## Jenkins Configuration

JCasC template:

```text
infra/ansible/templates/jenkins/jenkins.yaml.j2
```

Configured items:

- Local admin user.
- Logged-in admin authorization strategy.
- Worker node `jenkins-worker-1`.
- SSH credential `agent-ssh`.
- GitHub HTTPS credential `github-http`.
- Docker Hub credential `dockerhub`.
- Freestyle job `test-agent`.
- Pipeline job `deploy-capstone-app`.

Plugin list:

```text
infra/ansible/files/jenkins/plugins.txt
```

Important plugins:

- Configuration as Code
- Pipeline
- Git
- Job DSL
- SSH agent support through Jenkins SSH node plugin
- Pipeline Graph View

## Deploy Pipeline

Pipeline file:

```text
Jenkinsfile
```

Stages:

```text
Validate
Prepare Image Tag
Build Image
Push Image
Deploy
Smoke Test
Post Actions
```

Behavior:

1. Jenkins checks out `main`.
2. Builds the Docker image on the Jenkins worker.
3. Tags the image with the Git SHA and `latest`.
4. Logs into Docker Hub with a temporary Docker config.
5. Pushes both tags to Docker Hub.
6. SSHs to the app server.
7. App server logs into Docker Hub with a temporary Docker config.
8. App server pulls the exact Git SHA tag.
9. App server restarts the `capstone-nginx` container on port `8081`.
10. Jenkins runs a smoke test through SSH:

```text
curl -fsS http://127.0.0.1:8081
```

## App

Files:

- `app/index.html`
- `Dockerfile`

The app is a static Nginx page that displays the pipeline flow.

## Current Known Gaps

- GitHub webhook is not configured yet; Jenkins uses SCM polling.
- Terraform state is still local.
- Jenkins is exposed on public port `8080` during lab runs.
- Docker Hub token separation can be improved by using separate Terraform and Jenkins tokens.
