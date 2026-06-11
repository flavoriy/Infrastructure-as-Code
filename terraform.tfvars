aws_region                      = "ap-southeast-1"
aim_id                          = "ami-0a56f8447277affd8"
dev_subnet_cidr                 = "10.0.1.0/24"
prod_subnet_cidr                = "10.0.2.0/24"
dev_private_ips                 = ["10.0.1.10", "10.0.1.11", "10.0.1.12"]
prod_private_ips                = ["10.0.2.10", "10.0.2.11", "10.0.2.12"]
dev_public_ingress_cidr_blocks  = ["0.0.0.0/0"]
prod_public_ingress_cidr_blocks = ["0.0.0.0/0"]
project_name                    = "devops-project"
cpu_credits                     = "standard"
enable_detailed_monitoring      = false

ingress_ports_jenkins_server = [22, 8080]
volume_size_jenkins_server   = 15
instance_type_jenkins_server = "t2.small"

ingress_ports_jenkins_agent = [22]
volume_size_jenkins_agent   = 10
instance_type_jenkins_agent = "t2.micro"

ingress_ports_k3s_dev = [22, 6443, 30080, 30443]
volume_size_k3s_dev   = 15
instance_type_k3s_dev = "t2.small"

ingress_ports_k3s_prod = [22, 6443, 30080, 30443]
volume_size_k3s_prod   = 20
instance_type_k3s_prod = "t3a.medium"
key_name               = "jenkins-share-lib"
