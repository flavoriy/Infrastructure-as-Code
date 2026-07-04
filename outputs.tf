output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "dev_k3s_public_ip" {
  description = "Public IP for Dev K3s EC2 instance"
  value       = module.k3s_dev.public_ip
}

output "prod_eks_cluster_name" {
  description = "Prod EKS Cluster Name"
  value       = module.eks_prod.cluster_name
}

output "prod_eks_cluster_endpoint" {
  description = "Prod EKS Cluster API Endpoint"
  value       = module.eks_prod.cluster_endpoint
}
