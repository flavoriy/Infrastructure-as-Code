output "vpc_id" {
  value = module.vpc.vpc_id
}

output "dev_subnet_id" {
  value = module.vpc.dev_subnet_id
}

output "prod_subnet_ids" {
  value = module.vpc.prod_subnet_ids
}


output "k3s_dev_public_ip" {
  value = module.k3s_dev.public_ip
}

output "k3s_prod_public_ips" {
  value = [
    module.k3s_prod_server_1.public_ip,
    module.k3s_prod_server_2.public_ip,
    module.k3s_prod_server_3.public_ip,
  ]
}

output "k3s_prod_server_1_public_ip" {
  value = module.k3s_prod_server_1.public_ip
}

output "k3s_prod_server_2_public_ip" {
  value = module.k3s_prod_server_2.public_ip
}

output "k3s_prod_server_3_public_ip" {
  value = module.k3s_prod_server_3.public_ip
}

output "k3s_dev_private_ip" {
  value = var.dev_private_ips[0]
}

output "k3s_prod_private_ips" {
  value = var.prod_private_ips
}
