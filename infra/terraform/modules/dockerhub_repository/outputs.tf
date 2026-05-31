output "image_repository" {
  value = "docker.io/${var.namespace}/${var.name}"
}

output "name" {
  value = docker_hub_repository.this.name
}

output "namespace" {
  value = docker_hub_repository.this.namespace
}
