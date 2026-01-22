provider "aws" {
  region = var.aws_region
}

# Ubuntu 22.04 AMI (stable) via SSM
data "aws_ssm_parameter" "ubuntu_2204_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}


resource "aws_security_group" "capstone_sg" {
  name        = "capstone-sg"
  description = "SSH + Jenkins + App (restricted)"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "App"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "capstone-sg"
  }
}

resource "aws_security_group_rule" "ssh_from_self" {
  type                     = "ingress"
  description              = "SSH between instances in this SG"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.capstone_sg.id
  source_security_group_id = aws_security_group.capstone_sg.id
}


resource "aws_instance" "jenkins_manager" {
  ami                         = data.aws_ssm_parameter.ubuntu_2204_ami.value
  instance_type               = var.jenkins_manager_instance_type
  subnet_id                   = var.jenkins_manager_subnet_id
  vpc_security_group_ids      = [aws_security_group.capstone_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "capstone-jenkins-manager"
  }
}

resource "aws_instance" "jenkins_worker" {
  ami                         = data.aws_ssm_parameter.ubuntu_2204_ami.value
  instance_type               = var.jenkins_worker_instance_type
  subnet_id                   = var.jenkins_worker_subnet_id
  vpc_security_group_ids      = [aws_security_group.capstone_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "capstone-jenkins-worker"
  }
}

resource "aws_instance" "app_server" {
  ami                         = data.aws_ssm_parameter.ubuntu_2204_ami.value
  instance_type               = var.app_server_instance_type
  subnet_id                   = var.app_server_subnet_id
  vpc_security_group_ids      = [aws_security_group.capstone_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "capstone-app-server"
  }
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory/hosts.ini"

  content = templatefile("${path.module}/inventory.tpl", {
    jenkins_manager_ip         = aws_instance.jenkins_manager.public_ip
    jenkins_worker_public_ip   = aws_instance.jenkins_worker.public_ip
    jenkins_worker_private_ip  = aws_instance.jenkins_worker.private_ip
    app_server_ip              = aws_instance.app_server.public_ip
  })
}

