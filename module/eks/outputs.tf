output "cluster_name" {
  description = "EKS Cluster Name"
  value       = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  description = "EKS Cluster API Endpoint"
  value       = aws_eks_cluster.eks.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.eks.certificate_authority[0].data
}

output "cluster_arn" {
  description = "EKS Cluster ARN"
  value       = aws_eks_cluster.eks.arn
}

output "node_group_id" {
  description = "EKS Node Group ID"
  value       = aws_eks_node_group.nodes.id
}

output "node_role_name" {
  description = "IAM Role Name for EKS worker nodes"
  value       = aws_iam_role.node_role.name
}

output "node_role_arn" {
  description = "IAM Role ARN for EKS worker nodes"
  value       = aws_iam_role.node_role.arn
}

