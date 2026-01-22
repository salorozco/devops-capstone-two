output "jenkins_manager_public_ip" {
  value = aws_instance.jenkins_manager.public_ip
}

output "jenkins_worker_public_ip" {
  value = aws_instance.jenkins_worker.public_ip
}

output "app_server_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "ssh_commands" {
  value = {
    jenkins_manager = "ssh -o IdentitiesOnly=yes -i ~/.ssh/capstone-key.pem ubuntu@${aws_instance.jenkins_manager.public_ip}"
    jenkins_worker  = "ssh -o IdentitiesOnly=yes -i ~/.ssh/capstone-key.pem ubuntu@${aws_instance.jenkins_worker.public_ip}"
    app_server      = "ssh -o IdentitiesOnly=yes -i ~/.ssh/capstone-key.pem ubuntu@${aws_instance.app_server.public_ip}"
  }
}
