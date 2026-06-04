# Terraform Layout

This Terraform project is split into reusable modules and deployable stacks.
The goal is to keep infrastructure with different lifecycles in different
state files.

## Directory Map

```text
infra/terraform/
  terraform.tfvars

  modules/
    dockerhub_repository/
    ec2_instance/
    security_group/

  stacks/
    registry/
    ci/
    app/
```

`terraform.tfvars` contains local AWS values and is ignored by Git.

## Modules vs Stacks

A module is a reusable recipe. It does not own state by itself.

Examples:

```text
modules/ec2_instance
  creates one tagged EC2 instance

modules/security_group
  creates one security group with CIDR, source security group, and self rules

modules/dockerhub_repository
  creates one Docker Hub repository
```

A stack is a deployable root module. It calls modules and owns its own state.

Examples:

```text
stacks/registry
  owns Docker Hub repository state

stacks/ci
  owns Jenkins manager, Jenkins worker, and CI security group state

stacks/app
  owns app server and app security group state
```

## Lifecycle Boundaries

The stacks are split by what should be created and destroyed together.

| Stack | Owns | Lifecycle |
| --- | --- | --- |
| `registry` | Docker Hub repository | Long-lived. Usually preserved when AWS lab resources are destroyed. |
| `ci` | Jenkins manager, Jenkins worker, CI security group | Reusable CI platform. Can survive app rebuilds. |
| `app` | App server, app security group | Short-lived runtime. Can be destroyed independently. |

This means the app server can be torn down without deleting Jenkins, and AWS
resources can be torn down without deleting the Docker Hub repository.

## Stack Examples

The CI stack reuses the EC2 module twice:

```hcl
module "jenkins_manager" {
  source        = "../../modules/ec2_instance"
  ansible_group = "jenkins_manager"
  name          = "capstone-jenkins-manager"
}

module "jenkins_worker" {
  source        = "../../modules/ec2_instance"
  ansible_group = "jenkins_worker"
  name          = "capstone-jenkins-worker"
}
```

The app stack allows SSH from the CI security group. That is what lets Jenkins
deploy to the app server without opening SSH to the whole internet:

```hcl
ingress_source_security_group_rules = {
  ssh_from_ci = {
    description              = "SSH from Jenkins CI security group"
    from_port                = 22
    to_port                  = 22
    protocol                 = "tcp"
    source_security_group_id = var.ci_security_group_id
  }
}
```

The registry stack calls the Docker Hub module:

```hcl
module "repository" {
  source = "../../modules/dockerhub_repository"

  namespace = var.dockerhub_namespace
  name      = var.dockerhub_repository_name
}
```

## Full Deploy

Use the wrapper from the repo root:

```bash
./scripts/deploy_infra.sh
```

The wrapper applies stacks in this order:

```text
registry
ci
app
```

Then it runs Ansible with AWS dynamic inventory.

## Manual Stack Commands

Use these examples when testing one layer at a time.

Initialize and validate every stack:

```bash
terraform -chdir=infra/terraform/stacks/registry init
terraform -chdir=infra/terraform/stacks/registry validate

terraform -chdir=infra/terraform/stacks/ci init
terraform -chdir=infra/terraform/stacks/ci validate

terraform -chdir=infra/terraform/stacks/app init
terraform -chdir=infra/terraform/stacks/app validate
```

Plan the registry stack:

```bash
export DOCKER_USERNAME="$DOCKERHUB_USERNAME"
export DOCKER_PASSWORD="$DOCKERHUB_TOKEN"
export TF_VAR_dockerhub_namespace="${DOCKERHUB_NAMESPACE:-$DOCKERHUB_USERNAME}"
export TF_VAR_dockerhub_repository_name="${DOCKERHUB_REPOSITORY_NAME:-capstone-nginx}"

terraform -chdir=infra/terraform/stacks/registry plan
```

Plan the CI stack:

```bash
terraform -chdir=infra/terraform/stacks/ci plan \
  -var-file=../../terraform.tfvars
```

Plan the app stack after the CI stack exists:

```bash
ci_security_group_id="$(terraform -chdir=infra/terraform/stacks/ci output -raw ci_security_group_id)"

terraform -chdir=infra/terraform/stacks/app plan \
  -var-file=../../terraform.tfvars \
  -var "ci_security_group_id=$ci_security_group_id"
```

The app stack needs `ci_security_group_id` because it allows Jenkins to SSH to
the app server.

## Targeted Destroy

Destroy only the app server layer:

```bash
./scripts/destroy_app.sh
```

Destroy only the Jenkins layer after the app layer is gone:

```bash
./scripts/destroy_ci.sh
```

Destroy AWS lab resources while preserving Docker Hub:

```bash
./scripts/destroy_all_aws.sh
```

Destroy the registry stack only if the Docker Hub repository should be deleted:

```bash
terraform -chdir=infra/terraform/stacks/registry destroy
```

## State

State is local right now. Each stack has its own state file under its stack
directory.

```text
infra/terraform/stacks/registry/terraform.tfstate
infra/terraform/stacks/ci/terraform.tfstate
infra/terraform/stacks/app/terraform.tfstate
```

State files are ignored by Git. Do not commit them.

Remote state is not implemented yet. When remote state is added, each stack
should still have its own backend key so the lifecycle boundaries stay separate.

Example future backend keys:

```text
devops-capstone-two/registry/terraform.tfstate
devops-capstone-two/ci/terraform.tfstate
devops-capstone-two/app/terraform.tfstate
```

## Ansible Handoff

Terraform does not write a static Ansible inventory anymore. Instead, Terraform
tags EC2 instances:

```text
Project=devops-capstone-two
Environment=lab
AnsibleGroup=jenkins_manager | jenkins_worker | app_server
```

Ansible reads those tags with AWS dynamic inventory:

```bash
ansible-inventory -i infra/ansible/inventory/aws_ec2.yml --graph
```
