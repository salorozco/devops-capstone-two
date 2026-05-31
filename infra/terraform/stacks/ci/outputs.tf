output "ci_security_group_id" {
  value = module.ci_security_group.id
}

output "jenkins_manager_private_ip" {
  value = module.jenkins_manager.private_ip
}

output "jenkins_manager_public_ip" {
  value = module.jenkins_manager.public_ip
}

output "jenkins_worker_private_ip" {
  value = module.jenkins_worker.private_ip
}

output "jenkins_worker_public_ip" {
  value = module.jenkins_worker.public_ip
}

output "ssh_commands" {
  value = {
    jenkins_manager = "ssh -o IdentitiesOnly=yes -i ~/.ssh/capstone-key.pem ubuntu@${module.jenkins_manager.public_ip}"
    jenkins_worker  = "ssh -o IdentitiesOnly=yes -i ~/.ssh/capstone-key.pem ubuntu@${module.jenkins_worker.public_ip}"
  }
}
