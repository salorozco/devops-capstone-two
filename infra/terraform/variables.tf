variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "subnet_ids" {
  type        = list(string)
  description = "At least 2 subnet IDs in the default VPC"
}

variable "security_group_id" {
  type        = string
  description = "Security group ID to attach to all instances"
}

variable "key_name" {
  type        = string
  description = "EC2 Key Pair name for SSH"
}

variable "jenkins_manager_instance_type" {
  type    = string
  default = "t3.small"
}

variable "jenkins_worker_instance_type" {
  type    = string
  default = "t3.small"
}

variable "app_server_instance_type" {
  type    = string
  default = "t3.small"
}

variable "my_ip_cidr" {
  type        = string
  description = "Your public IP in CIDR form (example: 1.2.3.4/32)"
}

variable "app_port" {
  type        = number
  description = "Port for the app server container"
  default     = 8081
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy into"
}

variable "jenkins_manager_subnet_id" {
  type        = string
  description = "Subnet ID for Jenkins manager instance"
}

variable "jenkins_worker_subnet_id" {
  type        = string
  description = "Subnet ID for Jenkins worker instance"
  
}

variable "app_server_subnet_id" {
  type = string
  description = "Subnet"
}
