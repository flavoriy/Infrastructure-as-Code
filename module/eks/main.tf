module "cluster_iam" {
  source              = "../iam"
  project_name        = var.project_name
  role_name           = "${var.project_name}-${var.environment}-eks-cluster-role"
  assume_role_service = "eks.amazonaws.com"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ]
}

# EKS Cluster
resource "aws_eks_cluster" "eks" {
  #checkov:skip=CKV_AWS_39:Public endpoint access is required to access EKS cluster without a bastion/VPN in this lab
  #checkov:skip=CKV_AWS_38:Public endpoint CIDR restriction is omitted for simplicity in this lab
  #checkov:skip=CKV_AWS_58:Secrets encryption with KMS is disabled to avoid KMS key charges in this lab
  #checkov:skip=CKV_AWS_37:Control plane logging is disabled by default to save CloudWatch ingestion costs

  name     = "${var.project_name}-${var.environment}-eks"
  role_arn = module.cluster_iam.role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  depends_on = [
    module.cluster_iam
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks"
    Environment = var.environment
  }
}

module "node_iam" {
  source              = "../iam"
  project_name        = var.project_name
  role_name           = "${var.project_name}-${var.environment}-eks-node-role"
  assume_role_service = "ec2.amazonaws.com"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
}

resource "aws_launch_template" "eks_node_lt" {
  name_prefix   = "${var.project_name}-${var.environment}-node-lt-"
  
  block_device_mappings {
    device_name = "/dev/xvda"
    
    ebs {
      volume_size           = var.disk_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Managed Node Group using EC2 Spot Instances (Multi-AZ HA & 70% Cost Savings)
resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "${var.project_name}-${var.environment}-ha-spot-nodes"
  node_role_arn   = module.node_iam.role_arn
  subnet_ids      = var.subnet_ids

  capacity_type  = "SPOT"
  instance_types = var.node_instance_types
  
  launch_template {
    id      = aws_launch_template.eks_node_lt.id
    version = aws_launch_template.eks_node_lt.latest_version
  }

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    module.node_iam
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-spot-node"
    Environment = var.environment
  }
}
