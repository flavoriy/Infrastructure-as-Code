aws_region   = "ap-southeast-1"
aim_id       = "ami-0a56f8447277affd8"
subnet_cidr  = "10.0.1.0/24"
subnet_ip    = ["10.0.1.10", "10.0.1.11", "10.0.1.12", "10.0.1.13", "10.0.1.14"]
project_name = "jenkins-share-lib-project"

ingress_ports_jenkins_server = [22, 8080]
volume_size_jenkins_server   = 20
instance_type_jenkins_server = "m7i-flex.large"

ingress_ports_jenkins_agent = [22]
volume_size_jenkins_agent   = 20
instance_type_jenkins_agent = "m7i-flex.large"

ingress_ports_k3s = [22, 6443, 30080, 30443]
volume_size_k3s   = 20
instance_type_k3s = "m7i-flex.large"

ingress_ports_k3s_worker = [22, 30080, 30443]
volume_size_k3s_worker   = 20
instance_type_k3s_worker = "m7i-flex.large"

key_name = "jenkins-share-lib"
