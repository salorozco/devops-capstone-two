module "app_server" {
  source = "../../modules/ec2_instance"

  ami                = data.aws_ssm_parameter.ubuntu_2204_ami.value
  ansible_group      = "app_server"
  instance_type      = var.app_server_instance_type
  key_name           = var.key_name
  name               = "capstone-app-server"
  role               = "app-server"
  security_group_ids = [module.app_security_group.id]
  subnet_id          = var.app_server_subnet_id
  tags               = local.common_tags
}
