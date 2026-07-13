# TikTo AWS Infrastructure (IaC)

This repository defines the modular, production-ready AWS cloud infrastructure layer for the **TikTo** application using **Terraform**. It automates the provisioning of secure networking, compute, managed Kubernetes (Amazon EKS), centralized logging (AWS OpenSearch), and secure secrets storage (AWS Secrets Manager).

---

## 🗺️ System Architecture Topology

The infrastructure is designed with strict network segregation between public client traffic and administrative DevOps management traffic.

### Native System Flow (Mermaid Diagram)

```mermaid
graph TD
    %% Styles and colors
    classDef git fill:#F9F9F9,stroke:#D1D1D1,stroke-width:1px,color:#333;
    classDef public fill:#E8F4FD,stroke:#1E88E5,stroke-width:1.5px,color:#0D47A1;
    classDef private fill:#F3E5F5,stroke:#8E24AA,stroke-width:1.5px,color:#4A148C;
    classDef aws fill:#FFF3E0,stroke:#FB8C00,stroke-width:1.5px,color:#E65100;
    classDef vpn fill:#E8F5E9,stroke:#43A047,stroke-width:1.5px,color:#1B5E20;

    %% Outside VPC
    GitHub["GitHub Actions (CI/CD Pipeline)"]:::git
    User["End User (Public Client)"]:::git
    Admin["DevOps Engineer"]:::git
    Tailscale["Tailscale VPN (WireGuard Gateway)"]:::vpn

    subgraph AWS_Cloud ["AWS Cloud (Region: ap-southeast-1 Singapore)"]
        EKS_Control["AWS Managed EKS Control Plane"]:::aws

        subgraph VPC ["AWS VPC (10.0.0.0/16)"]
            %% Public Subnet
            subgraph Public_Subnet ["Public Subnets (Multi-AZ)"]
                IGW["Internet Gateway (IGW)"]:::public
                NAT["NAT Gateway"]:::public
                ALB["AWS Application Load Balancer"]:::public
                ArgoCD["Argo CD Server (EC2 Management)"]:::public
            end

            %% Private Subnets
            subgraph Private_Subnets ["Private Subnets (Multi-AZ)"]
                %% K3s Dev
                subgraph K3s_Dev ["Single-node K3s (Dev Cluster)"]
                    K3s_Pods["Dev Pods & Fluent Bit"]:::private
                end

                %% EKS Prod
                subgraph EKS_Prod ["AWS EKS Cluster (Production)"]
                    Ingress["EKS Ingress"]:::private
                    Service["K8s Service"]:::private
                    
                    subgraph Managed_Node_Group ["EKS Managed Node Group (Spot Instances)"]
                        Worker1["Worker Node 1 (App Pods, Fluent Bit)"]:::private
                        WorkerN["Worker Node N"]:::private
                    end
                    
                    LBC["AWS Load Balancer Controller"]:::private
                end

                %% VPC Endpoints
                VPCEndpoint["VPC PrivateLink Endpoints"]:::public
            end
        end

        %% Regional Services
        Secrets["AWS Secrets Manager"]:::aws
        OpenSearch["AWS OpenSearch Service<br>(OpenSearch Dashboards / Kibana)"]:::aws
    end

    %% External Controls & GitOps
    GitHub -->|Terraform Plan/Apply| AWS_Cloud
    Admin -->|Secure WireGuard Tunnel| Tailscale
    Tailscale -.->|Private Access (SSH/Web)| ArgoCD
    Tailscale -.->|K8s API Access| K3s_Dev
    Tailscale -.->|Kibana Logs Access| OpenSearch

    %% User Inbound Data Path (Public)
    User -->|HTTP/HTTPS (Port 80/443)| IGW
    IGW --> ALB
    ALB --> Ingress
    Ingress --> Service
    Service --> Worker1
    Service --> WorkerN

    %% Outbound Egress Traffic (NAT Gateway)
    K3s_Pods & Worker1 & WorkerN --> NAT
    NAT --> IGW
    IGW -->|Outbound Egress| Internet["Public Package Registries (NPM, Docker, etc.)"]:::git

    %% AWS Load Balancer Controller Loop
    Ingress -.->|Manages| LBC
    LBC -.->|Configures| ALB

    %% Private Link Access
    K3s_Pods & Worker1 & WorkerN --> VPCEndpoint
    VPCEndpoint --> Secrets
    VPCEndpoint --> OpenSearch
```

---

## 🚀 Key Architectural Capabilities

*   **Production High Availability**: Multi-AZ deployment spanning `ap-southeast-1a`, `ap-southeast-1b`, and `ap-southeast-1c`.
*   **Mixed Instance EKS Auto-Scaling**: The production EKS cluster is backed by a mixed Spot/On-Demand instance group (`t3.medium`, `t3a.medium`, `t2.medium`), cutting cluster compute costs by up to **70%**.
*   **Centralized VPC Logging**: Application logs are ingested via Fluent Bit on EKS nodes and pushed over private VPC links to a Multi-AZ **AWS OpenSearch** cluster.
*   **Zero-Trust Admin Gateway**: Public ingress is strictly limited to application routes. All administrative entry (Argo CD Dashboard, Kubernetes APIs, and Kibana logs) is routed through a secure **Tailscale VPN** subnet gateway.
*   **Automated Secrets Pipeline**: Sensitive keys are defined as Terraform variables and automatically populated in AWS Secrets Manager straight from GitHub Secrets during CI/CD execution, avoiding local `.env` parsing inside Terraform.

---

## 📂 Repository Structure

The directory is modularized to split cloud resource definitions from configuration scripts:

```text
IaC/
├── main.tf                 # Orchestration of all infrastructure modules
├── variables.tf            # Input variable declarations
├── outputs.tf              # Infrastructure output declarations
├── terraform.tfvars        # Global configuration parameters
├── secrets_and_iam.tf      # AWS Secrets Manager & EKS worker node IAM policies
├── .env.example            # Template for local environment variables
├── module/
│   ├── vpc/                # Multi-AZ VPC subnet networking
│   ├── ec2/                # Standalone EC2 instances (Argo CD & K3s Dev)
│   ├── eks/                # High-Availability EKS Cluster & Spot Node Group
│   ├── opensearch/         # Managed OpenSearch logging cluster
│   └── secrets_manager/    # Reusable AWS Secrets Manager secret store
└── scripts/
    ├── common/             # Base OS installation packages
    ├── k3s/                # Local k3s and Argo CD configuration
    └── nodes/              # Node-specific setup scripts (tracked in Git)
        ├── argo_server/    # Argo CD management server startup script
        └── k3s_dev/        # K3s dev server startup script
```

---

## 🔒 Security & Compliance Controls

The infrastructure is hardened against standard AWS vulnerabilities and checked against **Checkov** security policies:

*   **EBS Encryption**: All root and data volumes are encrypted at rest with AWS-managed keys.
*   **No Hardcoded Secrets**: Secrets are injected dynamically using environment variables (`TF_VAR_<name>`) in GitHub Actions.
*   **IMDSv2 Enforced**: Metadata options on EC2 instances require tokens (`http_tokens = "required"`) with a response hop limit of 1 to block SSRF attacks.
*   **Least Privilege IAM**:
    *   `secrets_manager_read`: Restricts Secret access strictly to EKS worker node roles (for the External Secrets Operator).
    *   `opensearch_ingest`: Restricts Log Ingestion HTTP actions strictly to Fluent Bit on EKS nodes.

---

## 🛠️ Deploying the Infrastructure

### 1. Prerequisites
Before deploying, ensure you have:
1.  An **AWS S3 Bucket** named `bucket-project-devops-tfstate` created in `ap-southeast-1` to act as the Terraform backend.
2.  An **AWS EC2 Key Pair** named `devops-project` generated in `ap-southeast-1` to manage access keys for standalone nodes.
3.  **GitHub Environment Secrets** configured on your repository for the `production` environment:

| GitHub Secret Key | Description |
|---|---|
| `DATABASE_URL` | Main application connection string |
| `CALENDAR_DATABASE_URL` | Calendar service connection string |
| `PROFILE_DATABASE_URL` | Profile service connection string |
| `TASKS_DATABASE_URL` | Tasks service connection string |
| `TIKTO_CALENDAR_API_URL` | Calendar service API endpoint |
| `TIKTO_DASHBOARD_API_URL` | Frontend Dashboard API endpoint |
| `TIKTO_PROFILE_API_URL` | Profile service API endpoint |
| `TIKTO_TASKS_API_URL` | Tasks service API endpoint |
| `NEXT_PUBLIC_APP_URL` | Public application URL |
| `SONAR_TOKEN` | SonarQube code scan token |
| `GITOPS_TOKEN` | GitOps repository PAT token |
| `GITOPS_USERNAME` | GitOps GitHub Username |
| `TOKEN_ENCRYPTION_KEY` | JWT/Cookie encryption key |
| `TAILSCALE_AUTHKEY` | VPN Node authentication key |

### 2. Execution (Local or CI/CD)
To provision the infrastructure manually from your local command line, export the variables and run:

```bash
# Export your AWS Credentials
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="ap-southeast-1"

# Export the variables (Example)
export TF_VAR_database_url="postgresql://..."
export TF_VAR_tailscale_authkey="tskey-auth-..."

# Run Terraform commands
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 3. Connect to EKS Cluster
Once provisioning completes, update your local Kubeconfig context:
```bash
aws eks update-kubeconfig --region ap-southeast-1 --name tikto-prod-eks
kubectl get nodes -o wide
```

---

## 📊 Infrastructure Summary Outputs

| Output Name | Description | Access Scope |
|---|---|---|
| `vpc_id` | AWS Network ID | Internal VPC |
| `argo_server_public_ip` | Public IP for dedicated Argo CD Server | Managed (VPN required) |
| `dev_k3s_public_ip` | Public IP for Dev K3s EC2 Node | Managed (VPN required) |
| `prod_eks_cluster_name` | Name of EKS production cluster (`tikto-prod-eks`) | K8s API Context |
| `opensearch_domain_endpoint`| Private domain VPC endpoint for OpenSearch logs | Internal VPC |
| `opensearch_kibana_endpoint`| Kibana dashboard web interface URL | VPN Connected Admins |
