module "app_security_group" {
  source = "../../modules/security_group"

  name        = "capstone-app-sg"
  description = "Application server access"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  ingress_cidr_rules = {
    ssh_from_operator = {
      description = "SSH from operator IP"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.my_ip_cidr]
    }
    app_from_operator = {
      description = "App from operator IP"
      from_port   = var.app_port
      to_port     = var.app_port
      protocol    = "tcp"
      cidr_blocks = [var.my_ip_cidr]
    }
  }

  ingress_source_security_group_rules = {
    ssh_from_ci = {
      description              = "SSH from Jenkins CI security group"
      from_port                = 22
      to_port                  = 22
      protocol                 = "tcp"
      source_security_group_id = var.ci_security_group_id
    }
  }

  egress_cidr_rules = {
    all_outbound = {
      description = "All outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
