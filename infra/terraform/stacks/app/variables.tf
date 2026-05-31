variable "app_port" {
  type        = number
  description = "Port for the app server container."
  default     = 8081
}

variable "app_server_instance_type" {
  type        = string
  description = "App server EC2 instance type."
  default     = "t3.small"
}

variable "app_server_subnet_id" {
  type        = string
  description = "Subnet ID for the app server."
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "ci_security_group_id" {
  type        = string
  description = "CI security group ID allowed to SSH to the app server."
}

variable "environment" {
  type        = string
  description = "Environment tag value."
  default     = "lab"
}

variable "jenkins_manager_instance_type" {
  type        = string
  description = "Unused shared tfvars compatibility value."
  default     = "t3.small"
}

variable "jenkins_manager_subnet_id" {
  type        = string
  description = "Unused shared tfvars compatibility value."
  default     = ""
}

variable "jenkins_worker_instance_type" {
  type        = string
  description = "Unused shared tfvars compatibility value."
  default     = "t3.small"
}

variable "jenkins_worker_subnet_id" {
  type        = string
  description = "Unused shared tfvars compatibility value."
  default     = ""
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name for SSH."
}

variable "my_ip_cidr" {
  type        = string
  description = "Operator public IP in CIDR form."
}

variable "project" {
  type        = string
  description = "Project tag value."
  default     = "devops-capstone-two"
}

variable "security_group_id" {
  type        = string
  description = "Unused shared tfvars compatibility value."
  default     = ""
}

variable "subnet_ids" {
  type        = list(string)
  description = "Unused shared tfvars compatibility value."
  default     = []
}

variable "vpc_id" {
  type        = string
  description = "VPC ID."
}
