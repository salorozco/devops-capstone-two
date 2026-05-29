# Current Infrastructure Flow

This file maps the current state of `devops-capstone-two` before we finish the pipeline.
It describes what is wired today, what each file is responsible for, and where the flow currently stops.

Date mapped: 2026-05-28
Last updated: 2026-05-29

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
   - Repo-root environment file: `.env`
4. Loads `.env` if it exists.
5. Requires `JENKINS_ADMIN_PASSWORD` from the shell environment or `.env`.
6. Runs `terraform init -upgrade`.
7. Runs `terraform apply -auto-approve`.
8. Checks that the generated Ansible inventory exists.
9. Prints the inventory.
10. Waits for SSH by running `ansible -i "$INV_FILE" all -m ping` up to 12 times.
11. Runs `ansible-playbook -i "$INV_FILE" site.yml`.
12. Prints `DONE`.

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

1. Requires `JENKINS_ADMIN_PASSWORD` from the Ansible control environment.
2. Installs prerequisites for Jenkins.
3. Installs Java 17 runtime.
4. Adds the Jenkins apt signing key.
5. Adds the Jenkins apt repository.
6. Installs Jenkins.
7. Stops Jenkins before plugin and config setup.
8. Copies `infra/ansible/files/jenkins/plugins.txt` to the controller.
9. Downloads the Jenkins plugin installation manager jar.
10. Installs Jenkins plugins into `/var/lib/jenkins/plugins`.
11. Creates `/var/lib/jenkins/.ssh`.
12. Generates an SSH keypair for the Jenkins controller if missing.
13. Reads the generated private key with Ansible logging disabled.
14. Reads the generated public key.
15. Authorizes the controller public key on the Jenkins worker before Jenkins starts.
16. Pulls the worker private IP from the generated inventory.
17. Creates the JCasC directory at `/var/lib/jenkins/casc`.
18. Renders `infra/ansible/templates/jenkins/jenkins.yaml.j2` with mode `0600` and Ansible logging disabled.
19. Writes a systemd override so Jenkins starts with:
    - setup wizard disabled
    - JCasC config path set
20. Starts Jenkins.
21. Waits for Jenkins on port `8080`.
22. Prints login and worker information without printing the admin password value.

Current Jenkins admin password source:

```text
JENKINS_ADMIN_PASSWORD
```

Current secret-handling state:

- The repo-root `.env` file is ignored by git.
- `.env.example` documents the required local variable.
- The rendered JCasC file is written with mode `0600` because it contains a private key.
- Sensitive private-key read/render tasks use `no_log: true`.

### Jenkins worker SSH authorization

Runs during:

- Jenkins manager bootstrap play, delegated to the Jenkins worker

Current behavior:

1. Reads the Jenkins controller public key on the manager.
2. Adds that public key to the worker `ubuntu` user's `authorized_keys` before Jenkins starts.

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
- Worker label string: `linux docker worker`.
- SSH launcher points to the worker private IP.
- Test job named `test-agent`.

Current state:

- The active JCasC template has one top-level `jenkins:` block.
- Jenkins security/admin config and the worker node config are in the same block.
- Credentials and jobs remain separate top-level JCasC sections.

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

## Test Agent Job

Defined in: `infra/ansible/templates/jenkins/jenkins.yaml.j2`

Current behavior:

- The active JCasC template defines one freestyle job called `test-agent`.
- Runs basic checks:
  - `whoami`
  - `hostname`
  - `java -version`
  - `docker --version`
  - `docker ps`

Current wiring state:

- The job uses label `worker`.
- The JCasC worker label is `linux docker worker`.
- The job should match the Jenkins worker.
- The old static JCasC file and standalone `seed.groovy` file were removed to keep one source of truth.

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

The Jenkins manager/worker bootstrap is now more complete. These are the remaining main gaps:

1. Add app server configuration in Ansible.
2. Add app server SSH access for Jenkins.
3. Add a real build/deploy flow.
4. Add or confirm needed Jenkins plugins for the deploy pipeline.
5. Decide whether unused Terraform variables should be removed or documented.
6. Add the `local` provider requirement because Terraform uses `local_file`.
7. Decide whether generated inventory should stay ignored and be recreated by Terraform.

## Current Jenkins Cleanup State

Completed after the original mapping:

- The duplicate active JCasC `jenkins:` blocks were merged.
- The worker label was changed to `linux docker worker`.
- The `test-agent` job is now defined inline in active JCasC.
- The old static `files/jenkins/jenkins.yaml` file was removed.
- The standalone `seed.groovy` file was removed.
- Jenkins admin password now comes from `JENKINS_ADMIN_PASSWORD`.
- The rendered JCasC file is written with mode `0600`.
- Sensitive private-key tasks use `no_log: true`.
