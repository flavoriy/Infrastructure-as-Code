variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "ap-southeast-1"
}

variable "cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "The CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_ip" {
  description = "IP addresses for the subnets"
  type        = list(string)
  default     = ["10.0.1.10", "10.0.1.11", "10.0.1.12", "10.0.1.13"]
}

variable "aim_id" {
  description = "The AMI ID for the EC2 instance"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "instance_state" {
  description = "The desired state of the EC2 instance (e.g., running, stopped)"
  type        = string
  default     = "running"
}

variable "ingress_ports_jenkins_server" {
  description = "List of ingress ports for the Jenkins server"
  type        = list(number)
  default     = [22, 8080]
}

variable "volume_size_jenkins_server" {
  description = "The size of the root EBS volume for the Jenkins server (in GB)"
  type        = number
  default     = 20
}

variable "ingress_ports_jenkins_agent" {
  description = "List of ingress ports for the Jenkins agent"
  type        = list(number)
  default     = [22]
}

variable "volume_size_jenkins_agent" {
  description = "The size of the root EBS volume for the Jenkins agent (in GB)"
  type        = number
  default     = 20
}

variable "ingress_ports_sonar_server" {
  description = "List of ingress ports for the SonarQube server"
  type        = list(number)
  default     = [22, 9000]
}

variable "volume_size_sonar_server" {
  description = "The size of the root EBS volume for the SonarQube server (in GB)"
  type        = number
  default     = 20
}

variable "ingress_ports_k3s" {
  description = "List of ingress ports for the k3s server"
  type        = list(number)
  default     = [22, 6443]
}

variable "volume_size_k3s" {
  description = "The size of the root EBS volume for the k3s server (in GB)"
  type        = number
  default     = 20
}

variable "key_name" {
  description = "The name of the SSH key pair to use for the EC2 instance"
  type        = string
  default     = "jenkins-share-lib.pem"
}