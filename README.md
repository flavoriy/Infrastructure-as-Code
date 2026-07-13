# TikTo Cloud Platform Infrastructure (IaC)

[![Terraform](https://img.shields.io/badge/Terraform-1.5%2B-blueviolet?style=flat&logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Singapore-orange?style=flat&logo=amazon-aws)](https://aws.amazon.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.31-blue?style=flat&logo=kubernetes)](https://kubernetes.io/)
[![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-orange?style=flat&logo=argo)](https://argoproj.github.io/cd/)

## 1. Executive Summary
This repository contains the definitive Infrastructure as Code (IaC) for the **TikTo** platform. It utilizes Terraform to provision a high-availability, multi-environment cloud ecosystem on AWS (`ap-southeast-1` Singapore). The architecture is designed with a "Security-First" and "GitOps-Ready" mindset, separating concerns between Production (EKS) and Development (K3s) workloads.

---

## 2. Infrastructure Architecture & Topology

The platform is deployed across a multi-tier VPC architecture. Direct admin access to the private subnets is securely handled via a Tailscale VPN Subnet Router.

### System Topology Diagram

```mermaid
graph TD
    %% Admin/Management Path
    Admin[DevOps Engineer] -->|Tailscale VPN| VPN[Tailscale Gateway]
    VPN -->|SSH/Web| ArgoCD[Argo CD EC2 Server]
    VPN -->|K8s API| K3sDev[K3s Dev EC2 Server]
    VPN -->|HTTPS| OpenSearch[OpenSearch Dashboards]

    %% GitOps Automation
    GitHub[GitHub Actions] -->|Terraform Plan/Apply| AWS[AWS Cloud]
    ArgoCD -->|Sync Workloads| EKS_Control[EKS Control Plane]
    EKS_Control -->|Deploy Pods| EKS_Nodes[EKS Worker Nodes]

    %% Public Traffic Path
    User[End User] -->|HTTP/HTTPS Port 80/443| IGW[Internet Gateway]
    IGW --> ALB[AWS Application Load Balancer]
    ALB --> EKS_Ingress[EKS Ingress]
    EKS_Ingress --> EKS_Nodes

    %% VPC Egress
    K3sDev --> NAT[NAT Gateway]
    EKS_Nodes --> NAT
    NAT --> IGW
    IGW --> Internet[Public Registries]

    %% Logging & Secrets (Private Link)
    EKS_Nodes --> VPCEndpoints[VPC Endpoints]
    VPCEndpoints --> Secrets[AWS Secrets Manager]
    VPCEndpoints --> OpenSearch
```

---

## 3. IaC Pillars

*   **Modular Design**: The infrastructure is composed of reusable, versioned modules (VPC, EC2, EKS, OpenSearch, Secrets Manager). This ensures consistency and prevents configuration drift.
*   **GitOps Delivery**: Cloud infrastructure serves as the foundation for Argo CD. Workload states are automatically reconciled against manifests defined in the GitOps repository.
*   **Security & Secrets Lifecycle**:
    *   *Least Privilege*: Granular IAM policies are attached to EKS worker node roles for passwordless log ingestion to OpenSearch and secrets retrieval.
    *   *Zero Hardcoded Secrets*: All application credentials are dynamically injected into AWS Secrets Manager straight from GitHub Secrets during CI/CD execution.
    *   *Workload Isolation*: Workloads run inside private subnets and access external networks securely via NAT Gateways.

---

## 4. Technology Stack

| Category | Tooling | Scope / Configuration |
| :--- | :--- | :--- |
| **Cloud Provider** | AWS (Amazon Web Services) | Region: `ap-southeast-1` (Singapore) |
| **Provisioning** | Terraform | CLI Version `>= 1.10` |
| **Orchestration** | Amazon EKS & K3s | Prod: EKS `v1.31` / Dev: K3s |
| **CI/CD / GitOps** | Argo CD | Dedicated EC2 Server (`t3.small`) |
| **Networking** | AWS VPC & Tailscale | VPC CIDR `10.0.0.0/16` / WireGuard VPN |
| **Logging** | AWS OpenSearch Service | Domain `v2.11` (Multi-AZ Data Nodes) |
| **Secret Management** | AWS Secrets Manager | Keys: `tikto/dev` & `tikto/prod` |

---

## 5. Repository Structure

```text
.
├── module/                 # Reusable Terraform modules
│   ├── vpc/                # Multi-AZ VPC networking
│   ├── ec2/                # Standalone EC2 instances (Argo CD & K3s Dev)
│   ├── eks/                # High-Availability EKS Cluster & Spot Node Group
│   ├── opensearch/         # Managed OpenSearch logging cluster
│   └── secrets_manager/    # Reusable AWS Secrets Manager module
├── scripts/                # Initialization and setup scripts
│   ├── common/             # OS package bootstrap scripts
│   ├── k3s/                # Local k3s and Argo CD configuration
│   └── nodes/              # Node-specific setup scripts (Argo CD & K3s Dev)
├── main.tf                 # Global orchestration logic
├── variables.tf            # Input variable declarations
├── outputs.tf              # Endpoints and metadata outputs
├── secrets_and_iam.tf      # Secrets Manager stores & IAM policy bindings
└── terraform.tfvars        # Default environment configuration
```

---

## 6. Deployment Workflow

### Prerequisites
1.  **AWS S3 Backend**: An S3 bucket named `bucket-project-devops-tfstate` created in `ap-southeast-1` to store the state file.
2.  **EC2 Key Pair**: An EC2 Key Pair named `devops-project` generated in `ap-southeast-1` for standalone EC2 instances.
3.  **GitHub Environment Secrets**: Configure the following secrets on your GitHub repository (under the `production` environment):

| Secret Key | Description | Example Value |
|---|---|---|
| `DATABASE_URL` | Application database connection string | `postgresql://postgres:MySecurePassword123!@tikto-db.rds.amazonaws.com:5432/tikto_db` |
| `CALENDAR_DATABASE_URL` | Calendar service database connection string | `postgresql://postgres:MySecurePassword123!@calendar-db.rds.amazonaws.com:5432/calendar_db` |
| `PROFILE_DATABASE_URL` | Profile service database connection string | `postgresql://postgres:MySecurePassword123!@profile-db.rds.amazonaws.com:5432/profile_db` |
| `TASKS_DATABASE_URL` | Tasks service database connection string | `postgresql://postgres:MySecurePassword123!@tasks-db.rds.amazonaws.com:5432/tasks_db` |
| `TIKTO_CALENDAR_API_URL` | Calendar service API endpoint | `https://api.calendar.tikto.example.com` |
| `TIKTO_DASHBOARD_API_URL` | Frontend Dashboard API endpoint | `https://api.dashboard.tikto.example.com` |
| `TIKTO_PROFILE_API_URL` | Profile service API endpoint | `https://api.profile.tikto.example.com` |
| `TIKTO_TASKS_API_URL` | Tasks service API endpoint | `https://api.tasks.tikto.example.com` |
| `NEXT_PUBLIC_APP_URL` | Public web application URL | `https://tikto.example.com` |
| `SONAR_TOKEN` | SonarQube scanner token | `sqa_abcdef1234567890abcdef1234567890` |
| `GITOPS_TOKEN` | GitHub PAT for GitOps repository | `github_pat_11ABCDEF01234567890abcdef` |
| `GITOPS_USERNAME` | GitOps GitHub Username | `devops-admin` |
| `TOKEN_ENCRYPTION_KEY` | JWT token encryption key | `super-secret-jwt-encryption-key-32-chars` |
| `TAILSCALE_AUTHKEY` | Tailscale subnet router auth key | `tskey-auth-k8s-abcdef1234567890-abcdef` |

### Step 1: Initialization
Initialize the backend and download provider plugins:
```bash
terraform init
```

### Step 2: Plan
Generate and review the execution plan to ensure alignment:
```bash
terraform plan -out=tfplan
```

### Step 3: Apply
Provision the infrastructure:
```bash
terraform apply tfplan
```

### Step 4: Connect to EKS
Once provisioning completes, update your local Kubeconfig:
```bash
aws eks update-kubeconfig --region ap-southeast-1 --name tikto-prod-eks
kubectl get nodes
```

---

## 7. Operational Notes

### Cost Optimization
The production EKS environment leverages AWS Spot Instances (`t3.medium`, `t3a.medium`, `t2.medium`) managed by the EKS Node Group, cutting compute costs by **70-90%** compared to On-Demand pricing.

### Secure Connectivity
Direct access to resources inside private subnets is handled via Tailscale. The `argo_server` instance runs a Tailscale subnet router, allowing authorized developers to access internal Kubernetes APIs and Kibana dashboards securely without exposing public ports.

---

## 8. Maintainers
**Infrastructure Team - TikTo Project**
This infrastructure is managed strictly via IaC. Manual changes via the AWS Console are prohibited to prevent state drift.
