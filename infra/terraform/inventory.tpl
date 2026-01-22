[jenkins_manager]
${jenkins_manager_ip} ansible_user=ubuntu

[jenkins_worker]
${jenkins_worker_ip} ansible_user=ubuntu

[app_server]
${app_server_ip} ansible_user=ubuntu

[all:vars]
ansible_ssh_private_key_file=~/.ssh/capstone-key.pem
ansible_ssh_common_args=-o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

