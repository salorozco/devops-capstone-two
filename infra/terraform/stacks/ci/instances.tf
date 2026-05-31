module "jenkins_manager" {
  source = "../../modules/ec2_instance"

  ami                = data.aws_ssm_parameter.ubuntu_2204_ami.value
  ansible_group      = "jenkins_manager"
  instance_type      = var.jenkins_manager_instance_type
  key_name           = var.key_name
  name               = "capstone-jenkins-manager"
  role               = "jenkins-manager"
  security_group_ids = [module.ci_security_group.id]
  subnet_id          = var.jenkins_manager_subnet_id
  tags               = local.common_tags
}

module "jenkins_worker" {
  source = "../../modules/ec2_instance"

  ami                = data.aws_ssm_parameter.ubuntu_2204_ami.value
  ansible_group      = "jenkins_worker"
  instance_type      = var.jenkins_worker_instance_type
  key_name           = var.key_name
  name               = "capstone-jenkins-worker"
  role               = "jenkins-worker"
  security_group_ids = [module.ci_security_group.id]
  subnet_id          = var.jenkins_worker_subnet_id
  tags               = local.common_tags
}
