# Current Infrastructure Flow

Last updated: 2026-05-31

The project is now split into Terraform modules and lifecycle-specific stacks.

## Stack Flow

```text
registry stack
  -> Docker Hub repository

ci stack
  -> Jenkins manager
  -> Jenkins worker
  -> CI security group

app stack
  -> App server
  -> App security group

Ansible
  -> discovers EC2 instances by tags
  -> configures Jenkins and app runtime
```

## Why Stacks

The project has resources with different lifecycles:

```text
Docker Hub repo
  long-lived
  kept when AWS lab resources are destroyed

Jenkins manager/worker
  reusable CI platform
  can survive app stack rebuilds

App server
  short-lived app runtime
  can be destroyed independently
```

That is why Terraform is split into:

```text
infra/terraform/stacks/registry
infra/terraform/stacks/ci
infra/terraform/stacks/app
```

Each stack is a Terraform root module and has its own local state.

Example state boundaries:

```text
stacks/registry/terraform.tfstate
  Docker Hub repo only

stacks/ci/terraform.tfstate
  Jenkins manager, Jenkins worker, CI security group

stacks/app/terraform.tfstate
  App server, app security group
```

## Modules

Reusable modules live under:

```text
infra/terraform/modules
```

Current modules:

```text
dockerhub_repository
ec2_instance
security_group
```

Stacks call modules. Modules do not own state by themselves.

## Deploy Script

File:

```text
scripts/deploy_infra.sh
```

The script:

1. Loads repo-root `.env`.
2. Requires Jenkins, GitHub, and Docker Hub credentials.
3. Applies the registry stack.
4. Applies the CI stack.
5. Reads `ci_security_group_id` from the CI stack.
6. Applies the app stack with that CI security group ID.
7. Shows Terraform outputs.
8. Uses Ansible AWS dynamic inventory.
9. Waits until all three EC2 hosts are reachable by SSH.
10. Runs `infra/ansible/site.yml`.

The app stack depends on the CI stack output. The deploy script passes that
value explicitly:

```bash
ci_security_group_id="$(terraform -chdir="$CI_STACK" output -raw ci_security_group_id)"

terraform -chdir="$APP_STACK" apply \
  -var-file="$TF_VAR_FILE" \
  -var "ci_security_group_id=$ci_security_group_id"
```

That keeps the two state files separate while still allowing the app security
group to trust SSH from Jenkins.

## Terraform Registry Stack

Path:

```text
infra/terraform/stacks/registry
```

Owns:

```text
docker_hub_repository
```

Output:

```text
image_repository
```

Example:

```text
docker.io/salorozco23/capstone-nginx
```

## Terraform CI Stack

Path:

```text
infra/terraform/stacks/ci
```

Owns:

```text
capstone-ci-sg
capstone-jenkins-manager
capstone-jenkins-worker
```

The CI security group allows:

- SSH from `my_ip_cidr`.
- Jenkins UI `8080` from `my_ip_cidr`.
- SSH between Jenkins manager and worker.
- All outbound traffic.

## Terraform App Stack

Path:

```text
infra/terraform/stacks/app
```

Owns:

```text
capstone-app-sg
capstone-app-server
```

The app security group allows:

- SSH from `my_ip_cidr`.
- App port `8081` from `my_ip_cidr`.
- SSH from the CI security group.
- All outbound traffic.

## Ansible Dynamic Inventory

Path:

```text
infra/ansible/inventory/aws_ec2.yml
```

It discovers running EC2 instances with:

```text
Project=devops-capstone-two
Environment=lab
```

It creates groups from:

```text
AnsibleGroup=jenkins_manager
AnsibleGroup=jenkins_worker
AnsibleGroup=app_server
```

The inventory composes host vars:

```text
ansible_host
ansible_user
ansible_ssh_private_key_file
jenkins_private_ip
app_private_ip
```

## Ansible Playbook

Path:

```text
infra/ansible/site.yml
```

It configures:

- Jenkins worker with Java and Docker.
- App server with Docker and curl.
- Jenkins manager with Jenkins, plugins, credentials, JCasC, node, and jobs.

Jenkins restart handlers run when plugin config, JCasC, or systemd config changes.

## Jenkins Deploy Pipeline

Path:

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

The deploy stage SSHs to the app server, pulls the image from Docker Hub, restarts the container, and then smoke-tests it.

## Current Known Gaps

- Remote Terraform state is not implemented yet.
- GitHub webhook is not implemented yet.
- Jenkins still uses public port `8080` restricted by `my_ip_cidr`.
- Docker Hub credentials are still sourced from local `.env`.
