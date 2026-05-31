resource "docker_hub_repository" "this" {
  namespace        = var.namespace
  name             = var.name
  description      = var.description
  full_description = var.full_description
  private          = var.private
}
