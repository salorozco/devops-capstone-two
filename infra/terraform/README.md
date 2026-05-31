# Terraform Layout

This Terraform project is split into modules and stacks.

## Modules

Modules are reusable infrastructure recipes:

```text
modules/dockerhub_repository
modules/ec2_instance
modules/security_group
```

Modules do not own state by themselves. Stacks call modules.

## Stacks

Stacks are deployable units with lifecycle boundaries:

```text
stacks/registry
stacks/ci
stacks/app
```

Each stack is a Terraform root module with its own local state.

## Lifecycle Boundaries

```text
registry
  Docker Hub repo
  long-lived

ci
  Jenkins manager and worker
  reusable platform infrastructure

app
  App server
  short-lived application runtime
```

## Shared Variables

AWS stack variables are read from:

```text
infra/terraform/terraform.tfvars
```

That file is ignored by Git.

## Full Deploy

Use the wrapper from the repo root:

```bash
./scripts/deploy_infra.sh
```

The wrapper applies stacks in the correct order and then runs Ansible.
