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

# 2. Dev Environment: Single EC2 Instance for K3s (Single Node)
module "k3s_dev" {
  source              = "./module/ec2"
  instance_name       = "k3s_dev"
  vpc_id              = module.vpc.vpc_id
  project_name        = var.project_name
  aws_ami_id          = var.ami_id
  aws_instance_type   = var.instance_type_k3s_dev
  key_name            = var.key_name
  subnet_id           = module.vpc.dev_subnet_id
  private_ip          = var.dev_private_ips[0]
  ingress_ports       = var.ingress_ports_k3s_dev
  admin_ingress_ports = var.admin_ports_k3s_dev
  volume_size         = var.volume_size_k3s_dev
}

# 3. Prod Environment: High Availability Amazon EKS Cluster (Multi-AZ Managed NodeGroup)
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
