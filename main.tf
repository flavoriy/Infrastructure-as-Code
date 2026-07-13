terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "bucket-project-devops-tfstate"
    key          = "terraform.tfstate"
    region       = "ap-southeast-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. Reusable VPC Module (Dev Subnet + Multi-AZ Prod Subnets)
module "vpc" {
  source            = "./module/vpc"
  project_name      = var.project_name
  aws_region        = var.aws_region
  cidr_block        = var.cidr_block
  dev_subnet_cidr   = var.dev_subnet_cidr
  prod_subnet_cidrs = var.prod_subnet_cidrs
}

# 2. Management Environment: Dedicated Argo CD Server EC2
module "argo_server" {
  source            = "./module/ec2"
  instance_name     = "argo_server"
  vpc_id            = module.vpc.vpc_id
  project_name      = var.project_name
  aws_ami_id        = var.ami_id
  aws_instance_type = var.instance_type_argo_server
  key_name          = var.key_name
  subnet_id         = module.vpc.dev_subnet_id
  private_ip        = var.argo_server_private_ip
  volume_size       = var.volume_size_argo_server
  associate_eip     = false
  user_data = join("\n", [
    "#!/bin/bash",
    "export TAILSCALE_AUTHKEY=\"${var.tailscale_authkey}\"",
    "export PRIVATE_IP=\"${var.argo_server_private_ip}\"",
    "export NODE_NAME=\"argo-server\"",
    file("${path.module}/scripts/nodes/argo_server/setup.bash")
  ])

  ingress_rules = concat(
    [
      for port in var.ingress_ports_argo_server : {
        from_port   = port
        to_port     = port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow public TCP port ${port}"
      }
    ],
    [
      for port in var.admin_ports_argo_server : {
        from_port   = port
        to_port     = port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow admin TCP port ${port}"
      }
    ]
  )
}

# 3. Dev Environment: Single EC2 Instance for K3s (Single Node)
module "k3s_dev" {
  source            = "./module/ec2"
  instance_name     = "k3s_dev"
  vpc_id            = module.vpc.vpc_id
  project_name      = var.project_name
  aws_ami_id        = var.ami_id
  aws_instance_type = var.instance_type_k3s_dev
  key_name          = var.key_name
  subnet_id         = module.vpc.dev_subnet_id
  private_ip        = var.dev_private_ips[0]
  volume_size       = var.volume_size_k3s_dev
  associate_eip     = false
  user_data = join("\n", [
    "#!/bin/bash",
    "export PRIVATE_IP=\"${var.dev_private_ips[0]}\"",
    "export NODE_NAME=\"k3s-dev\"",
    file("${path.module}/scripts/nodes/k3s_dev/setup.bash")
  ])

  ingress_rules = concat(
    [
      for port in var.ingress_ports_k3s_dev : {
        from_port   = port
        to_port     = port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow public TCP port ${port}"
      }
    ],
    [
      for port in var.admin_ports_k3s_dev : {
        from_port   = port
        to_port     = port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow admin TCP port ${port}"
      }
    ]
  )
}

# 4. Prod Environment: High Availability Amazon EKS Cluster (Multi-AZ Managed NodeGroup)
module "eks_prod" {
  source              = "./module/eks"
  project_name        = var.project_name
  environment         = "prod"
  cluster_version     = var.eks_cluster_version
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.prod_subnet_ids
  node_instance_types = var.eks_node_instance_types
  desired_size        = var.eks_desired_size
  min_size            = var.eks_min_size
  max_size            = var.eks_max_size
}

# 5. Prod Environment: AWS OpenSearch Service Managed Cluster for Centralized Logging
module "opensearch_prod" {
  source         = "./module/opensearch"
  project_name   = var.project_name
  environment    = "prod"
  vpc_id         = module.vpc.vpc_id
  vpc_cidr_block = var.cidr_block
  subnet_ids     = [module.vpc.prod_subnet_ids[0], module.vpc.prod_subnet_ids[1]]
  engine_version = var.opensearch_engine_version
  instance_type  = var.opensearch_instance_type
  instance_count = var.opensearch_instance_count
  volume_size    = var.opensearch_volume_size
  volume_type    = var.opensearch_volume_type
}


