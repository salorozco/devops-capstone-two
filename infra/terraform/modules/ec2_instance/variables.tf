variable "ami" {
  type        = string
  description = "AMI ID to use for the instance."
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Whether to associate a public IP address."
  default     = true
}

variable "ansible_group" {
  type        = string
  description = "Value for the AnsibleGroup tag used by dynamic inventory."
  default     = ""
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name."
}

variable "name" {
  type        = string
  description = "Name tag for the instance."
}

variable "role" {
  type        = string
  description = "Role tag for the instance."
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs to attach to the instance."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the instance."
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to the instance."
  default     = {}
}
