variable "description" {
  type        = string
  description = "Security group description."
}

variable "egress_cidr_rules" {
  type = map(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  description = "Egress rules using CIDR blocks."
  default     = {}
}

variable "ingress_cidr_rules" {
  type = map(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  description = "Ingress rules using CIDR blocks."
  default     = {}
}

variable "ingress_self_rules" {
  type = map(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
  }))
  description = "Ingress rules that reference this security group."
  default     = {}
}

variable "ingress_source_security_group_rules" {
  type = map(object({
    description              = string
    from_port                = number
    to_port                  = number
    protocol                 = string
    source_security_group_id = string
  }))
  description = "Ingress rules that reference another security group."
  default     = {}
}

variable "name" {
  type        = string
  description = "Security group name."
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to the security group."
  default     = {}
}

variable "vpc_id" {
  type        = string
  description = "VPC ID."
}
