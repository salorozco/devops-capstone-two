variable "namespace" {
  type        = string
  description = "Docker Hub user or organization namespace that owns the repository."
}

variable "name" {
  type        = string
  description = "Docker Hub repository name."
}

variable "description" {
  type        = string
  description = "Short Docker Hub repository description."
  default     = "Capstone app image repository"
}

variable "full_description" {
  type        = string
  description = "Full Docker Hub repository description."
  default     = "Container images built and deployed by the Jenkins capstone pipeline."
}

variable "private" {
  type        = bool
  description = "Whether the Docker Hub repository should be private."
  default     = false
}
