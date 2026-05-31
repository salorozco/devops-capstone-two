# DevOps Capstone Two

This repo is an AWS-based Jenkins CI/CD lab. It uses Terraform stacks for infrastructure lifecycle boundaries, Ansible for server configuration, Jenkins Configuration as Code for Jenkins state, and Docker Hub as the image registry.

## Architecture

Application delivery flow:

```text
GitHub main
  -> Jenkins pipeline
  -> Docker image build on Jenkins worker
  -> Docker Hub push
  -> App server pull
  -> Container restart
  -> Smoke test
```

Provisioning flow:

```text
scripts/deploy_infra.sh
  -> Terraform registry stack
  -> Terraform CI stack
  -> Terraform app stack
  -> Ansible AWS dynamic inventory
  -> Ansible configures Jenkins manager, worker, and app server
```

## Terraform Layout

Terraform is split by lifecycle, not just by file size.

```text
infra/terraform/
  modules/
    dockerhub_repository/
    ec2_instance/
    security_group/

  stacks/
    registry/
    ci/
    app/
```

Modules are reusable infrastructure recipes. Stacks are deployable units with their own state.

### Registry Stack

Owns Docker Hub repository lifecycle:

```text
docker.io/<DOCKERHUB_NAMESPACE>/<DOCKERHUB_REPOSITORY_NAME>
```

This stack is long-lived and should usually survive AWS teardown.

### CI Stack

Owns Jenkins platform infrastructure:

```text
Jenkins manager EC2
Jenkins worker EC2
CI security group
```

This stack can be reused across app deployments.

### App Stack

Owns app runtime infrastructure:

```text
App server EC2
App security group
```

This stack can be destroyed independently from Jenkins and Docker Hub.

## Ansible Inventory

Ansible now uses AWS dynamic inventory instead of a Terraform-generated `hosts.ini`.

Inventory file:

```text
infra/ansible/inventory/aws_ec2.yml
```

Terraform tags EC2 instances with:

```text
Project=devops-capstone-two
Environment=lab
AnsibleGroup=jenkins_manager | jenkins_worker | app_server
```

Ansible discovers the running EC2 instances from those tags.

## What Ansible Configures

- Baseline apt cache updates on all servers.
- Java and Docker on the Jenkins worker.
- Docker and curl on the app server.
- Jenkins installation on the manager.
- Jenkins plugins, including Pipeline and Pipeline Graph View.
- Jenkins admin user through JCasC.
- Jenkins credentials for GitHub, Docker Hub, and SSH.
- Jenkins worker node.
- `test-agent` validation job.
- `deploy-capstone-app` pipeline job.

## Jenkins Pipeline

The deploy job watches `main` with SCM polling and runs the root `Jenkinsfile`.

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

The image is tagged with the Git commit SHA and also pushed as `latest`.

Example:

```text
docker.io/salorozco23/capstone-nginx:<git-sha>
docker.io/salorozco23/capstone-nginx:latest
```

The app server pulls the exact Git SHA image tag and restarts the `capstone-nginx` container on port `8081`.

## Required Local Environment

Create a repo-root `.env` file:

```bash
JENKINS_ADMIN_PASSWORD='your-jenkins-admin-password'
GITHUB_USERNAME='your-github-username'
GITHUB_TOKEN='your-github-token'
DOCKERHUB_USERNAME='your-dockerhub-username'
DOCKERHUB_TOKEN='your-dockerhub-token'
DOCKERHUB_NAMESPACE='your-dockerhub-username-or-org'
DOCKERHUB_REPOSITORY_NAME='capstone-nginx'
```

Create `infra/terraform/terraform.tfvars` with AWS values:

```hcl
aws_region                = "us-east-1"
jenkins_manager_subnet_id = "subnet-..."
jenkins_worker_subnet_id  = "subnet-..."
app_server_subnet_id      = "subnet-..."
key_name                  = "your-ec2-keypair"
my_ip_cidr                = "x.x.x.x/32"
vpc_id                    = "vpc-..."
```

Do not commit `.env` or `terraform.tfvars`.

## Full Deploy

From the repo root:

```bash
./scripts/deploy_infra.sh
```

This applies the stacks in order:

```text
registry
ci
app
```

Then it runs Ansible against dynamic AWS inventory.

After provisioning, Jenkins is available at:

```text
http://<JENKINS_MANAGER_PUBLIC_IP>:8080
```

The app is available after a successful deploy job at:

```text
http://<APP_SERVER_PUBLIC_IP>:8081
```

## Targeted Teardown

Destroy only the app stack:

```bash
./scripts/destroy_app.sh
```

Destroy only the CI stack after app is gone:

```bash
./scripts/destroy_ci.sh
```

Destroy AWS lab resources while preserving Docker Hub:

```bash
./scripts/destroy_all_aws.sh
```

The registry stack is intentionally not destroyed by `destroy_all_aws.sh`.

## Validation

```bash
cd infra/terraform/stacks/registry
terraform validate
```

```bash
cd infra/terraform/stacks/ci
terraform validate
```

```bash
cd infra/terraform/stacks/app
terraform validate
```

```bash
cd infra/ansible
ansible-playbook --syntax-check site.yml
```

```bash
bash -n scripts/deploy_infra.sh
bash -n scripts/deploy_app.sh
```

## Notes

- Remote Terraform state is not implemented yet.
- GitHub webhooks are not implemented yet; Jenkins currently uses SCM polling.
- The Docker Hub repo is a separate stack because it has a different lifecycle from the AWS lab resources.
