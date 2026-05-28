# Current Infrastructure Flow

This file maps the current state of `devops-capstone-two` before we finish the pipeline.
It describes what is wired today, what each file is responsible for, and where the flow currently stops.

Date mapped: 2026-05-28

## High-level Goal

The project is currently shaped as a Jenkins-on-EC2 CI/CD lab:

1. Terraform creates AWS infrastructure.
2. Terraform writes an Ansible inventory file from the created EC2 public/private IPs.
3. Ansible configures the EC2 instances.
4. Jenkins is installed on the manager instance.
5. Jenkins is intended to use a worker EC2 instance as an agent.
6. A future Jenkins job should build/deploy an app to the app server.

The last part is not fully wired yet.

## Current Repo Flow

```text
scripts/deploy_infra.sh
  |
  v
infra/terraform/main.tf
  |
  | creates AWS resources
  | writes infra/ansible/inventory/hosts.ini
  v
infra/ansible/site.yml
  |
  | configures Jenkins manager
  | configures Jenkins worker
  | only lightly touches app_server through the baseline play
  v
Jenkins controller on EC2
  |
  | should connect to Jenkins worker over SSH
  v
Jenkins worker EC2

App server EC2 exists, but no real deploy flow is connected yet.
```

## Deploy Script

File: `scripts/deploy_infra.sh`

Current behavior:

1. Uses strict Bash mode with `set -euo pipefail`.
2. Calculates the repo root from the script location.
3. Defines:
   - Terraform directory: `infra/terraform`
   - Ansible directory: `infra/ansible`
   - Generated inventory path: `infra/ansible/inventory/hosts.ini`
4. Runs `terraform init -upgrade`.
5. Runs `terraform apply -auto-approve`.
6. Checks that the generated Ansible inventory exists.
7. Prints the inventory.
8. Waits for SSH by running `ansible -i "$INV_FILE" all -m ping` up to 12 times.
9. Runs `ansible-playbook -i "$INV_FILE" site.yml`.
10. Prints `DONE`.

Important: this script creates or updates AWS resources because it runs `terraform apply`.

## Terraform Flow

Main files:

- `infra/terraform/main.tf`
- `infra/terraform/variables.tf`
- `infra/terraform/outputs.tf`
- `infra/terraform/inventory.tpl`
- `infra/terraform/versions.tf`

Terraform currently does this:

1. Uses the AWS provider in `var.aws_region`.
2. Reads the current Ubuntu 22.04 AMI ID from AWS SSM Parameter Store.
3. Creates one security group named `capstone-sg`.
4. Allows inbound SSH on port `22` from `var.my_ip_cidr`.
5. Allows inbound Jenkins UI traffic on port `8080` from `var.my_ip_cidr`.
6. Allows inbound app traffic on `var.app_port` from `var.my_ip_cidr`.
7. Allows all outbound traffic.
8. Adds a separate self-referencing security group rule that allows SSH between instances in the same security group.
9. Creates three EC2 instances:
   - `capstone-jenkins-manager`
   - `capstone-jenkins-worker`
   - `capstone-app-server`
10. Assigns each instance a public IP.
11. Places each instance into a subnet passed through variables.
12. Writes `infra/ansible/inventory/hosts.ini` using `inventory.tpl`.

Current Terraform variables that must be supplied:

- `key_name`
- `my_ip_cidr`
- `vpc_id`
- `jenkins_manager_subnet_id`
- `jenkins_worker_subnet_id`
- `app_server_subnet_id`

Current Terraform defaults:

- `aws_region = "us-east-1"`
- `jenkins_manager_instance_type = "t3.small"`
- `jenkins_worker_instance_type = "t3.small"`
- `app_server_instance_type = "t3.small"`
- `app_port = 8081`

Current Terraform outputs:

- Jenkins manager public IP
- Jenkins worker public IP
- App server public IP
- SSH command examples for all three instances

## Generated Ansible Inventory

Template file: `infra/terraform/inventory.tpl`

Terraform renders the inventory into:

```text
infra/ansible/inventory/hosts.ini
```

Current inventory groups:

- `[jenkins_manager]`
- `[jenkins_worker]`
- `[app_server]`

Current extra host variable:

- The Jenkins worker gets `jenkins_private_ip`.

Current limitation:

- The app server does not get an app private IP variable.
- The inventory hardcodes the SSH key path as `~/.ssh/capstone-key.pem`.

## Ansible Flow

Main file: `infra/ansible/site.yml`

### Play 1: Baseline setup on all servers

Runs on:

- Jenkins manager
- Jenkins worker
- App server

Current behavior:

- Updates the apt cache.

This is currently the only task that runs on the app server.

### Play 2: Jenkins worker setup

Runs on:

- Jenkins worker

Current behavior:

1. Installs Java 17 runtime.
2. Installs Docker.
3. Enables and starts Docker.
4. Adds the `ubuntu` user to the `docker` group.
5. Creates `/home/ubuntu/jenkins` as the Jenkins remote workspace.

Purpose:

- Prepare this EC2 instance to act as a Jenkins build agent.

### Play 3: Jenkins manager install and bootstrap

Runs on:

- Jenkins manager

Current behavior:

1. Installs prerequisites for Jenkins.
2. Installs Java 17 runtime.
3. Adds the Jenkins apt signing key.
4. Adds the Jenkins apt repository.
5. Installs Jenkins.
6. Stops Jenkins before plugin and config setup.
7. Copies `infra/ansible/files/jenkins/plugins.txt` to the controller.
8. Downloads the Jenkins plugin installation manager jar.
9. Installs Jenkins plugins into `/var/lib/jenkins/plugins`.
10. Creates `/var/lib/jenkins/.ssh`.
11. Generates an SSH keypair for the Jenkins controller if missing.
12. Reads the generated private key.
13. Reads the generated public key.
14. Pulls the worker private IP from the generated inventory.
15. Creates the JCasC directory at `/var/lib/jenkins/casc`.
16. Renders `infra/ansible/templates/jenkins/jenkins.yaml.j2`.
17. Writes a systemd override so Jenkins starts with:
    - setup wizard disabled
    - JCasC config path set
18. Starts Jenkins.
19. Waits for Jenkins on port `8080`.
20. Prints login and worker information.

Current hardcoded Jenkins admin password:

```text
ChangeMe-Admin-Password
```

Current concern:

- The rendered JCasC file is written with mode `0644`, but it contains a private key.

### Play 4: Authorize Jenkins controller SSH key on worker

Runs on:

- Jenkins worker

Current behavior:

1. Reads the Jenkins controller public key from the manager.
2. Adds that public key to the worker `ubuntu` user's `authorized_keys`.

Purpose:

- Allows the Jenkins controller to connect to the worker over SSH.

Current limitation:

- The app server does not receive this key, so Jenkins does not yet have a configured SSH path to deploy there.

## Jenkins Configuration

Current active JCasC template:

```text
infra/ansible/templates/jenkins/jenkins.yaml.j2
```

Current intended Jenkins setup:

- Local `admin` user.
- Logged-in users can administer Jenkins.
- SSH private key credential named `agent-ssh`.
- Permanent node named `jenkins-worker-1`.
- Worker remote filesystem: `/home/ubuntu/jenkins`.
- Worker label string: `linux docker`.
- SSH launcher points to the worker private IP.

Current issue:

- The template currently has two top-level `jenkins:` sections.
- YAML/JCasC may treat the second `jenkins:` block as replacing the first one.
- That means the node block and the security/admin block need to be merged before this is reliable.

## Jenkins Plugins

Current plugin list:

File: `infra/ansible/files/jenkins/plugins.txt`

```text
configuration-as-code
ssh-slaves
credentials
ssh-credentials
workflow-aggregator
git
job-dsl
```

Purpose:

- Configuration as Code support.
- SSH-based Jenkins agents.
- Credentials support.
- Pipeline support.
- Git support.
- Job DSL support.

Possible missing plugin for the next stage:

- `ssh-agent`, if the deploy pipeline uses an SSH credential inside a Jenkins pipeline step.

## Seed Job

File: `infra/ansible/files/jenkins/seed.groovy`

Current behavior:

- Defines one freestyle job called `test-agent`.
- Runs basic checks:
  - `whoami`
  - `hostname`
  - `java -version`
  - `docker --version`
  - `docker ps`

Current issue:

- The job uses label `worker`.
- The current JCasC worker label is `linux docker`.
- The job will not match the worker unless the worker label includes `worker` or the job label is changed.

Current wiring issue:

- The active JCasC template does not currently create a seed job.
- There is an older static JCasC file at `infra/ansible/files/jenkins/jenkins.yaml` that contains a `jobs:` block, but `site.yml` renders the newer template instead.
- So `seed.groovy` exists, but it is not currently wired into the active Jenkins config.

## App Server Flow

Current app server state:

1. Terraform creates the EC2 app server.
2. Terraform puts it in the Ansible inventory under `[app_server]`.
3. Ansible baseline play updates apt cache on it.

What is missing:

- Docker is not installed on the app server.
- No deploy directory is created.
- Jenkins controller public key is not authorized on the app server.
- No Jenkins pipeline deploys anything to it.
- No app code or Docker run flow is currently wired.

## Current Gaps Before Finishing Project 2

The infrastructure is partially complete. These are the main gaps to plan before editing:

1. Fix the active JCasC template so it has one valid `jenkins:` block.
2. Decide whether the Jenkins worker label should be `linux docker worker` or whether the job label should change.
3. Wire the seed job into active JCasC, or replace it with a real pipeline job.
4. Add app server configuration in Ansible.
5. Add app server SSH access for Jenkins.
6. Add a real build/deploy flow.
7. Add or confirm needed Jenkins plugins.
8. Avoid hardcoding the Jenkins admin password.
9. Protect the rendered JCasC file because it contains a private key.
10. Decide whether unused Terraform variables should be removed or documented.
11. Add the `local` provider requirement because Terraform uses `local_file`.
12. Decide whether generated inventory should stay ignored and be recreated by Terraform.

## Current Git State Notes

At the time this was mapped, the repo already had local changes in:

- `infra/ansible/files/jenkins/jenkins.yaml`
- `infra/ansible/files/jenkins/plugins.txt`
- `infra/ansible/site.yml`
- `infra/terraform/inventory.tpl`
- `infra/terraform/main.tf`

The generated inventory was deleted from git status:

- `infra/ansible/inventory/hosts.ini`

There is also an untracked template directory:

- `infra/ansible/templates/`

These are documented as current local state, not reverted.
