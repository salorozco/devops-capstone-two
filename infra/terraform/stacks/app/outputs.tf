output "app_security_group_id" {
  value = module.app_security_group.id
}

output "app_server_private_ip" {
  value = module.app_server.private_ip
}

output "app_server_public_ip" {
  value = module.app_server.public_ip
}

output "ssh_commands" {
  value = {
    app_server = "ssh -o IdentitiesOnly=yes -i ~/.ssh/capstone-key.pem ubuntu@${module.app_server.public_ip}"
  }
}
