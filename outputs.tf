output "vpc_id" {
  value = module.vpc.vpc_id
}

output "jenkins_server_public_ip" {
  value = module.jenkins_server.public_ip
}

output "jenkins_agent_public_ip" {
  value = module.jenkins_agent.public_ip
}

output "sonar_server_public_ip" {
  value = module.sonar_server.public_ip
}

output "k3s_public_ip" {
  value = module.k3s.public_ip
}
