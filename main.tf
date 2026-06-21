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


module "vpc" {
  source            = "./module/vpc"
  project_name      = var.project_name
  aws_region        = var.aws_region
  cidr_block        = var.cidr_block
  dev_subnet_cidr   = var.dev_subnet_cidr
  prod_subnet_cidrs = var.prod_subnet_cidrs
}


module "k3s_dev" {
  instance_name       = "k3s_dev"
  source              = "./module/ec2"
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


module "k3s_prod_server_1" {
  instance_name               = "k3s_prod_server_1"
  source                      = "./module/ec2"
  vpc_id                      = module.vpc.vpc_id
  project_name                = var.project_name
  aws_ami_id                  = var.ami_id
  aws_instance_type           = var.instance_type_k3s_prod
  key_name                    = var.key_name
  subnet_id                   = module.vpc.prod_subnet_ids[0]
  private_ip                  = var.prod_private_ips[0]
  ingress_ports               = var.ingress_ports_k3s_prod
  admin_ingress_ports         = var.admin_ports_k3s_prod
  private_ingress_ports       = var.private_ingress_ports_k3s_prod
  private_ingress_udp_ports   = var.private_ingress_udp_ports_k3s_prod
  private_ingress_cidr_blocks = var.prod_subnet_cidrs
  volume_size                 = var.volume_size_k3s_prod
}

module "k3s_prod_server_2" {
  instance_name               = "k3s_prod_server_2"
  source                      = "./module/ec2"
  vpc_id                      = module.vpc.vpc_id
  project_name                = var.project_name
  aws_ami_id                  = var.ami_id
  aws_instance_type           = var.instance_type_k3s_prod
  key_name                    = var.key_name
  subnet_id                   = module.vpc.prod_subnet_ids[1]
  private_ip                  = var.prod_private_ips[1]
  ingress_ports               = var.ingress_ports_k3s_prod
  admin_ingress_ports         = var.admin_ports_k3s_prod
  private_ingress_ports       = var.private_ingress_ports_k3s_prod
  private_ingress_udp_ports   = var.private_ingress_udp_ports_k3s_prod
  private_ingress_cidr_blocks = var.prod_subnet_cidrs
  volume_size                 = var.volume_size_k3s_prod
}

module "k3s_prod_server_3" {
  instance_name               = "k3s_prod_server_3"
  source                      = "./module/ec2"
  vpc_id                      = module.vpc.vpc_id
  project_name                = var.project_name
  aws_ami_id                  = var.ami_id
  aws_instance_type           = var.instance_type_k3s_prod
  key_name                    = var.key_name
  subnet_id                   = module.vpc.prod_subnet_ids[2]
  private_ip                  = var.prod_private_ips[2]
  ingress_ports               = var.ingress_ports_k3s_prod
  admin_ingress_ports         = var.admin_ports_k3s_prod
  private_ingress_ports       = var.private_ingress_ports_k3s_prod
  private_ingress_udp_ports   = var.private_ingress_udp_ports_k3s_prod
  private_ingress_cidr_blocks = var.prod_subnet_cidrs
  volume_size                 = var.volume_size_k3s_prod
}
