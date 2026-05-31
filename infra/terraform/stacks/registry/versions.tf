terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "docker/docker"
      version = "~> 0.6"
    }
  }
}
