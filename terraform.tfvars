aws_region                  ="ap-southeast-1"
aim_id                      ="ami-0c55b159cbfafe1f0"
subnet_cidr                 ="10.0.1.0/24"
subnet_ip                   =["10.0.1.1","10.0.1.2","10.0.1.3","10.0.1.4"]
project_name                = "devops-project"

ingress_ports_jenkins_server= [22, 8080]
volume_size_jenkins_server  = 20

ingress_ports_jenkins_agent = [22]
volume_size_jenkins_agent   = 20

ingress_ports_sonar_server  = [22, 9000]
volume_size_sonar_server    = 20

ingress_ports_k3s           = [22, 6443]
volume_size_k3s             = 20

key_name                    = "jenkins-share-lib.pem"
instance_state              = "running"  //"stopped" to stop the instance, "running" to start the instance
