module "ci_security_group" {
  source = "../../modules/security_group"

  name        = "capstone-ci-sg"
  description = "Jenkins manager and worker access"
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
    jenkins_from_operator = {
      description = "Jenkins UI from operator IP"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = [var.my_ip_cidr]
    }
  }

  ingress_self_rules = {
    ssh_between_ci_instances = {
      description = "SSH between Jenkins manager and worker"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
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
