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

### Mental Model

The closest programming comparison is:

```text
Terraform module       = reusable class or constructor
module variables       = constructor inputs
module resources       = reusable implementation
module outputs         = public return values
stack                  = application code that creates and connects module instances
stack state            = record of the real infrastructure created by that stack
```

This is composition, not inheritance. A stack can instantiate the same module
multiple times with different inputs.

For example, the CI stack creates two different EC2 instances from the same
`ec2_instance` module:

```text
module.jenkins_manager
  -> modules/ec2_instance
  -> one Jenkins manager EC2 instance

module.jenkins_worker
  -> modules/ec2_instance
  -> one Jenkins worker EC2 instance
```

The app stack also uses the same module:

```text
module.app_server
  -> modules/ec2_instance
  -> one app server EC2 instance
```

### Module File Roles

Terraform loads every `.tf` file in a directory together. Filenames such as
`main.tf`, `variables.tf`, and `outputs.tf` are conventions for readability,
not an execution order.

The `ec2_instance` module is organized like this:

```text
modules/ec2_instance/
  variables.tf  declares the inputs accepted by the module
  main.tf       contains the EC2 resource and internal local values
  outputs.tf    exposes selected EC2 attributes to callers
  versions.tf   declares the AWS provider requirement
```

Terraform treats those files as one module:

```text
variables.tf + main.tf + outputs.tf + versions.tf = ec2_instance module
```

That is also why the registry stack has a `main.tf`, while the larger CI and app
stacks use files such as `instances.tf` and `security_group.tf`. The filenames
can differ without changing Terraform behavior.

### Stack and Module Variable Scope

Stack variables and module variables use the same Terraform syntax, but they
are separate values in separate scopes.

The CI stack declares a variable for its Jenkins manager:

```hcl
# stacks/ci/variables.tf
variable "jenkins_manager_instance_type" {
  type    = string
  default = "t3.small"
}
```

The EC2 module declares a more general input:

```hcl
# modules/ec2_instance/variables.tf
variable "instance_type" {
  type = string
}
```

The module call connects them:

```hcl
module "jenkins_manager" {
  source = "../../modules/ec2_instance"

  instance_type = var.jenkins_manager_instance_type
}
```

The left side is the module input. The right side is the stack variable:

```text
instance_type                        = var.jenkins_manager_instance_type
module variable name                   stack variable name
```

The names do not have to match. The complete value flow is:

```text
terraform.tfvars
  -> stack var.jenkins_manager_instance_type
  -> module input instance_type
  -> module var.instance_type
  -> aws_instance.this.instance_type
```

### Module Outputs and Stack Outputs

Modules expose only the values that callers need. The EC2 module creates an
internal resource named `aws_instance.this` and exposes its IP addresses:

```hcl
# modules/ec2_instance/outputs.tf
output "public_ip" {
  value = aws_instance.this.public_ip
}
```

The CI stack reads that module output and can expose it again as a stack output:

```hcl
# stacks/ci/outputs.tf
output "jenkins_manager_public_ip" {
  value = module.jenkins_manager.public_ip
}
```

The complete output flow is:

```text
aws_instance.this.public_ip
  -> module.jenkins_manager.public_ip
  -> stack output jenkins_manager_public_ip
  -> terraform output
```

### What Owns the Resource

The module defines how to create a resource, but the calling stack owns the
created resource in its state.

For example, the Jenkins manager resource is recorded in the CI stack state
with an address similar to:

```text
module.jenkins_manager.aws_instance.this
```

The app server is recorded in the app stack state:

```text
module.app_server.aws_instance.this
```

They use the same reusable module implementation, but they are separate real
resources owned by separate stacks.

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

The registry value flow starts in the repo-root `.env` file. Terraform does not
read `.env` directly, so `scripts/deploy_infra.sh` exports values in the names
expected by Terraform and the Docker Hub provider:

```text
.env DOCKERHUB_USERNAME
  -> DOCKER_USERNAME
  -> Docker Hub provider authentication

.env DOCKERHUB_TOKEN
  -> DOCKER_PASSWORD
  -> Docker Hub provider authentication

.env DOCKERHUB_NAMESPACE
  -> TF_VAR_dockerhub_namespace
  -> stack var.dockerhub_namespace
  -> module input namespace
  -> module var.namespace
  -> docker_hub_repository.this.namespace
```

Authentication values answer who is allowed to call Docker Hub. Terraform
variables describe which repository should exist.

## How Terraform Evaluates a Stack

When Terraform runs against a stack directory, it:

1. Loads every `.tf` file in that stack directory.
2. Reads the stack variables from defaults, `terraform.tfvars`, `-var`,
   `-var-file`, or `TF_VAR_` environment variables.
3. Loads the modules referenced by each `module` block.
4. Passes stack values into module inputs.
5. Builds a dependency graph from module outputs and resource references.
6. Uses the configured providers to create, update, or destroy resources.
7. Records the resulting resources in that stack's state file.

For the CI stack, the dependency graph includes:

```text
CI security group
  -> Jenkins manager EC2 instance
  -> Jenkins worker EC2 instance
```

Both EC2 module calls depend on the security group module output:

```hcl
security_group_ids = [module.ci_security_group.id]
```

Terraform understands that the security group must exist before the instances
can be created.

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
