# TikTo AWS Infrastructure (IaC)

This repository defines the modular, production-ready AWS cloud infrastructure layer for the **TikTo** application using **Terraform**. It automates the provisioning of secure networking, compute, managed Kubernetes (Amazon EKS), centralized logging (AWS OpenSearch), and secure secrets storage (AWS Secrets Manager).

---

## 🗺️ System Architecture Topology

The infrastructure is designed with strict network segregation between public client traffic and administrative DevOps management traffic.

### System Flow (Basic Flowchart)

```mermaid
graph TD
    %% Admin/Management Path
    Admin[DevOps Engineer] -->|Tailscale VPN Tunnel| Tailscale[Tailscale Subnet Gateway]
    Tailscale -->|Private Web/SSH| ArgoCD[Argo CD EC2 Server]
    Tailscale -->|Private K8s API| K3sDev[K3s Dev EC2 Server]
    Tailscale -->|Private HTTPS| OpenSearch[OpenSearch Dashboards]

    %% GitOps Automation
    GitHub[GitHub Actions] -->|Terraform Plan/Apply| AWS[AWS Cloud]
    ArgoCD -->|Sync Workloads| EKS_Control[EKS Control Plane]
    EKS_Control -->|Deploy Pods| EKS_Nodes[EKS Worker Nodes]

    %% Public Traffic Path
    User[End User] -->|HTTP/HTTPS Port 80/443| IGW[Internet Gateway]
    IGW --> ALB[AWS Application Load Balancer]
    ALB --> EKS_Ingress[EKS Application Ingress]
    EKS_Ingress --> EKS_Nodes

    %% VPC Egress
    K3sDev --> NAT[NAT Gateway]
    EKS_Nodes --> NAT
    NAT --> IGW
    IGW --> Internet[Public Package Registries]

    %% Logging & Secrets (Private Link)
    EKS_Nodes --> VPCEndpoints[VPC Endpoints]
    VPCEndpoints --> Secrets[AWS Secrets Manager]
    VPCEndpoints --> OpenSearch
```

### Infrastructure Summary Table

| Environment | Component | Private IP / Subnet | Instance Type / Version | Ingress Control |
|---|---|---|---|---|
| **Management** | `argo_server` | `10.0.1.10` | EC2 `t3.small` / k3s + Argo CD | Restricted to Tailscale VPN |
| **Development**| `k3s_dev` | `10.0.1.12` | EC2 `t3.small` / Single-node K3s | TCP 30080/30443 NodePorts |
| **Production** | `eks_prod` | `10.0.2.0/24`<br>`10.0.3.0/24`<br>`10.0.4.0/24` | AWS EKS `v1.31` (Spot NodeGroup) | Public AWS Application Load Balancer |
| **Prod Logs** | `opensearch` | `10.0.2.0/24`<br>`10.0.3.0/24` | OpenSearch `v2.11` (Multi-AZ) | HTTPS 443 within VPC / VPN |
| **Secrets** | Secrets Manager | - | `tikto/dev` & `tikto/prod` stores | Private VPC Endpoint |

---

## 🛠️ Deploying the Infrastructure

### 1. Prerequisites
Before deploying, ensure you have:
1.  An **AWS S3 Bucket** named `bucket-project-devops-tfstate` created in `ap-southeast-1` to act as the Terraform backend.
2.  An **AWS EC2 Key Pair** named `devops-project` generated in `ap-southeast-1` to manage access keys for standalone nodes.
3.  **GitHub Environment Secrets** configured on your repository for the `production` environment:

| GitHub Secret Key | Description | Example / Template Value |
|---|---|---|
| `DATABASE_URL` | Main application database connection string | `postgresql://postgres:MySecurePassword123!@tikto-db.rds.amazonaws.com:5432/tikto_db` |
| `CALENDAR_DATABASE_URL` | Calendar service database connection string | `postgresql://postgres:MySecurePassword123!@calendar-db.rds.amazonaws.com:5432/calendar_db` |
| `PROFILE_DATABASE_URL` | Profile service database connection string | `postgresql://postgres:MySecurePassword123!@profile-db.rds.amazonaws.com:5432/profile_db` |
| `TASKS_DATABASE_URL` | Tasks service database connection string | `postgresql://postgres:MySecurePassword123!@tasks-db.rds.amazonaws.com:5432/tasks_db` |
| `TIKTO_CALENDAR_API_URL` | Calendar service API endpoint | `https://api.calendar.tikto.example.com` |
| `TIKTO_DASHBOARD_API_URL` | Frontend Dashboard API endpoint | `https://api.dashboard.tikto.example.com` |
| `TIKTO_PROFILE_API_URL` | Profile service API endpoint | `https://api.profile.tikto.example.com` |
| `TIKTO_TASKS_API_URL` | Tasks service API endpoint | `https://api.tasks.tikto.example.com` |
| `NEXT_PUBLIC_APP_URL` | Public web application URL | `https://tikto.example.com` |
| `SONAR_TOKEN` | SonarQube code scan token | `sqa_abcdef1234567890abcdef1234567890` |
| `GITOPS_TOKEN` | GitOps repository Personal Access Token | `github_pat_11ABCDEF01234567890abcdef` |
| `GITOPS_USERNAME` | GitOps GitHub Username | `devops-admin` |
| `TOKEN_ENCRYPTION_KEY` | JWT/Cookie secret encryption key | `super-secret-jwt-encryption-key-32-chars` |
| `TAILSCALE_AUTHKEY` | VPN Subnet Router authentication key | `tskey-auth-k8s-abcdef1234567890-abcdef` |

### 2. Execution (Local or CI/CD)
To provision the infrastructure manually from your local command line, export the variables and run:

```bash
# 1. Export your AWS Credentials
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="ap-southeast-1"

# 2. Export the variables with your values
export TF_VAR_database_url="postgresql://postgres:MySecurePassword123!@tikto-db.rds.amazonaws.com:5432/tikto_db"
export TF_VAR_tailscale_authkey="tskey-auth-k8s-abcdef1234567890-abcdef"
# (Export other TF_VAR_<name> variables as needed)

# 3. Run Terraform commands
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 3. Connect to EKS Cluster
Once provisioning completes, update your local Kubeconfig context to manage the cluster:
```bash
aws eks update-kubeconfig --region ap-southeast-1 --name tikto-prod-eks
kubectl get nodes -o wide
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
