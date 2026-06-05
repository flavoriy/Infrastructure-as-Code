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
  aws_instance_type = "m7i-flex.large"
  key_name          = var.key_name
  subnet_id         = module.vpc.subnet_id
  private_ip        = var.subnet_ip[0]
  ingress_ports     = var.ingress_ports_jenkins_server
  volume_size       = var.volume_size_jenkins_server
  instance_state    = var.instance_state
}


module "jenkins_agent" {
  instance_name     = "jenkins_agent"
  source            = "./module/ec2"
  vpc_id            = module.vpc.vpc_id
  project_name      = var.project_name
  aws_ami_id        = var.aim_id
  aws_instance_type = "m7i-flex.large"
  key_name          = var.key_name
  subnet_id         = module.vpc.subnet_id
  private_ip        = var.subnet_ip[1]
  ingress_ports     = var.ingress_ports_jenkins_agent
  volume_size       = var.volume_size_jenkins_agent
  instance_state    = var.instance_state
}

module "sonar_server" {
  instance_name     = "sonarqube_server"
  source            = "./module/ec2"
  vpc_id            = module.vpc.vpc_id
  project_name      = var.project_name
  aws_ami_id        = var.aim_id
  aws_instance_type = "m7i-flex.large"
  key_name          = var.key_name
  subnet_id         = module.vpc.subnet_id
  private_ip        = var.subnet_ip[2]
  ingress_ports     = var.ingress_ports_sonar_server
  volume_size       = var.volume_size_sonar_server
  instance_state    = var.instance_state
}



module "k3s" {
  instance_name     = "k3s"
  source            = "./module/ec2"
  vpc_id            = module.vpc.vpc_id
  project_name      = var.project_name
  aws_ami_id        = var.aim_id
  aws_instance_type = "m7i-flex.large"
  key_name          = var.key_name
  subnet_id         = module.vpc.subnet_id
  private_ip        = var.subnet_ip[3]
  ingress_ports     = var.ingress_ports_k3s
  volume_size       = var.volume_size_k3s
  instance_state    = var.instance_state
}