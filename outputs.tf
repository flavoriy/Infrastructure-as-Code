output "vpc_id" {
  value = module.vpc.vpc_id
}

output "jenkins_server_public_ip" {
  value = module.jenkins_server.public_ip
}

output "jenkins_agent_public_ip" {
  value = module.jenkins_agent.public_ip
}

output "k3s_dev_public_ip" {
  value = module.k3s_dev.public_ip
}

output "k3s_prod_public_ips" {
  value = [
    module.k3s_prod_master.public_ip,
    module.k3s_prod_worker.public_ip,
  ]
}

output "k3s_prod_master_public_ip" {
  value = module.k3s_prod_master.public_ip
}

output "k3s_prod_worker_public_ip" {
  value = module.k3s_prod_worker.public_ip
}

output "k3s_dev_private_ip" {
  value = var.subnet_ip[2]
}

output "k3s_prod_private_ips" {
  value = [
    var.subnet_ip[3],
    var.subnet_ip[4],
  ]
}
