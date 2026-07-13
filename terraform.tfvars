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

# Dedicated Argo CD Management Server
argo_server_private_ip    = "10.0.1.10"
instance_type_argo_server = "t3.small"
volume_size_argo_server   = 20
ingress_ports_argo_server = [80, 443, 30080, 30443]
admin_ports_argo_server   = [22, 6443]

# AWS OpenSearch Managed Cluster Settings (Centralized Logging)
opensearch_engine_version = "OpenSearch_2.11"
opensearch_instance_type  = "t3.medium.search"
opensearch_instance_count = 2
opensearch_volume_size    = 30
opensearch_volume_type    = "gp3"

# AWS Secrets Manager Settings
secret_key_dev  = "tikto/dev-v2"
secret_key_prod = "tikto/prod-v2"

