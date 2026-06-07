terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "bucket-project-devops-tfstate"
    key            = "terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
provider "aws" {
  region = var.aws_region
}


module "vpc" {
  source       = "./module/vpc"
  project_name = var.project_name
  aws_region   = var.aws_region
  cidr_block   = var.cidr_block
  subnet_cidr  = var.subnet_cidr
}


module "jenkins_server" {
  instance_name     = "jenkins_server"
  source            = "./module/ec2"
  vpc_id            = module.vpc.vpc_id
  project_name      = var.project_name
  aws_ami_id        = var.aim_id
  aws_instance_type = var.instance_type_jenkins_server
  key_name          = var.key_name
  subnet_id         = module.vpc.subnet_id
  private_ip        = var.subnet_ip[0]
  ingress_ports     = var.ingress_ports_jenkins_server
  volume_size       = var.volume_size_jenkins_server
}


module "jenkins_agent" {
  instance_name     = "jenkins_agent"
  source            = "./module/ec2"
  vpc_id            = module.vpc.vpc_id
  project_name      = var.project_name
  aws_ami_id        = var.aim_id
  aws_instance_type = var.instance_type_jenkins_agent
  key_name          = var.key_name
  subnet_id         = module.vpc.subnet_id
  private_ip        = var.subnet_ip[1]
  ingress_ports     = var.ingress_ports_jenkins_agent
  volume_size       = var.volume_size_jenkins_agent
}

module "k3s_worker_1" {
  instance_name     = "k3s_worker_1"
  source            = "./module/ec2"
  vpc_id            = module.vpc.vpc_id
  project_name      = var.project_name
  aws_ami_id        = var.aim_id
  aws_instance_type = var.instance_type_k3s_worker
  key_name          = var.key_name
  subnet_id         = module.vpc.subnet_id
  private_ip        = var.subnet_ip[2]
  ingress_ports     = var.ingress_ports_k3s_worker
  volume_size       = var.volume_size_k3s_worker
}



module "k3s" {
  instance_name     = "k3s"
  source            = "./module/ec2"
  vpc_id            = module.vpc.vpc_id
  project_name      = var.project_name
  aws_ami_id        = var.aim_id
  aws_instance_type = var.instance_type_k3s
  key_name          = var.key_name
  subnet_id         = module.vpc.subnet_id
  private_ip        = var.subnet_ip[3]
  ingress_ports     = var.ingress_ports_k3s
  volume_size       = var.volume_size_k3s
}

module "k3s_worker_2" {
  instance_name     = "k3s_worker_2"
  source            = "./module/ec2"
  vpc_id            = module.vpc.vpc_id
  project_name      = var.project_name
  aws_ami_id        = var.aim_id
  aws_instance_type = var.instance_type_k3s_worker
  key_name          = var.key_name
  subnet_id         = module.vpc.subnet_id
  private_ip        = var.subnet_ip[4]
  ingress_ports     = var.ingress_ports_k3s_worker
  volume_size       = var.volume_size_k3s_worker
}
