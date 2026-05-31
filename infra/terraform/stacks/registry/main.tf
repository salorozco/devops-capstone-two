module "repository" {
  source = "../../modules/dockerhub_repository"

  namespace = var.dockerhub_namespace
  name      = var.dockerhub_repository_name
  private   = var.dockerhub_repository_private
}
