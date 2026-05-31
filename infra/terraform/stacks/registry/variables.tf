variable "dockerhub_namespace" {
  type        = string
  description = "Docker Hub user or organization namespace that owns the app image repository."
}

variable "dockerhub_repository_name" {
  type        = string
  description = "Docker Hub repository name for the app image."
  default     = "capstone-nginx"
}

variable "dockerhub_repository_private" {
  type        = bool
  description = "Whether the Docker Hub app image repository should be private."
  default     = false
}
