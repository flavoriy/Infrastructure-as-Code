aws_region        = "ap-southeast-1"
ami_id            = "ami-0a56f8447277affd8"
dev_subnet_cidr   = "10.0.1.0/24"
prod_subnet_cidrs = ["10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
dev_private_ips   = ["10.0.1.12"]
prod_private_ips  = ["10.0.2.10", "10.0.3.10", "10.0.4.10"]
project_name      = "devops-project"

ingress_ports_k3s_dev = [30080, 30443]
admin_ports_k3s_dev   = [22, 6443]
volume_size_k3s_dev   = 15
instance_type_k3s_dev = "t2.small"

ingress_ports_k3s_prod = [30080, 30443]
admin_ports_k3s_prod   = [22, 6443]
volume_size_k3s_prod   = 20
instance_type_k3s_prod = "t3a.medium"
key_name               = "devops-project"
