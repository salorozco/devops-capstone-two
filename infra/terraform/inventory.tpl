[jenkins_manager]
${jenkins_manager_public_ip} ansible_user=ubuntu

[jenkins_worker]
${jenkins_worker_public_ip} ansible_user=ubuntu jenkins_private_ip=${jenkins_worker_private_ip}

[app_server]
${app_server_public_ip} ansible_user=ubuntu app_private_ip=${app_server_private_ip}

[all:vars]
ansible_ssh_private_key_file=~/.ssh/capstone-key.pem
ansible_ssh_common_args=-o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
