# Common Infrastructure Settings
aws_region   = "ap-southeast-1"
project_name = "tikto"
key_name     = "devops-project"
ami_id       = "ami-0a56f8447277affd8"

# Network Subnets
cidr_block        = "10.0.0.0/16"
dev_subnet_cidr   = "10.0.1.0/24"
prod_subnet_cidrs = ["10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
dev_private_ips   = ["10.0.1.12"]

# Dev Environment (Single EC2 K3s Node)
instance_type_k3s_dev = "t3.small"
volume_size_k3s_dev   = 20
ingress_ports_k3s_dev = [30080, 30443]
admin_ports_k3s_dev   = [22, 6443]

# Prod Environment (AWS EKS Cluster HA - Spot Nodes)
eks_cluster_version     = "1.31"
eks_node_instance_types = ["t3.medium", "t3a.medium", "t2.medium"]
eks_desired_size        = 3
eks_min_size            = 2
eks_max_size            = 5
