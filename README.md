# TikTo AWS Infrastructure (IaC)

This repository defines the modular AWS cloud infrastructure layer for the **TikTo** application using **Terraform** (networking, compute, EKS, OpenSearch logging, and Secrets Manager).

---

## 🗺️ System Topology

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

## 🛠️ Prerequisites & GitHub Secrets

Configure the following secrets on your GitHub repository (under `production` environment) before running the deployment pipeline:

| Secret Key | Description | Example Value |
|---|---|---|
| `DATABASE_URL` | Main database connection string | `postgresql://postgres:MySecurePassword123!@tikto-db.rds.amazonaws.com:5432/tikto_db` |
| `CALENDAR_DATABASE_URL` | Calendar service database connection string | `postgresql://postgres:MySecurePassword123!@calendar-db.rds.amazonaws.com:5432/calendar_db` |
| `PROFILE_DATABASE_URL` | Profile service database connection string | `postgresql://postgres:MySecurePassword123!@profile-db.rds.amazonaws.com:5432/profile_db` |
| `TASKS_DATABASE_URL` | Tasks service database connection string | `postgresql://postgres:MySecurePassword123!@tasks-db.rds.amazonaws.com:5432/tasks_db` |
| `TIKTO_CALENDAR_API_URL` | Calendar service API endpoint | `https://api.calendar.tikto.example.com` |
| `TIKTO_DASHBOARD_API_URL` | Frontend Dashboard API endpoint | `https://api.dashboard.tikto.example.com` |
| `TIKTO_PROFILE_API_URL` | Profile service API endpoint | `https://api.profile.tikto.example.com` |
| `TIKTO_TASKS_API_URL` | Tasks service API endpoint | `https://api.tasks.tikto.example.com` |
| `NEXT_PUBLIC_APP_URL` | Public web application URL | `https://tikto.example.com` |
| `SONAR_TOKEN` | SonarQube scanner token | `sqa_abcdef1234567890abcdef1234567890` |
| `GITOPS_TOKEN` | Personal Access Token for GitOps repository | `github_pat_11ABCDEF01234567890abcdef` |
| `GITOPS_USERNAME` | GitOps GitHub Username | `devops-admin` |
| `TOKEN_ENCRYPTION_KEY` | JWT/Cookie secret encryption key | `super-secret-jwt-encryption-key-32-chars` |
| `TAILSCALE_AUTHKEY` | Tailscale subnet router authentication key | `tskey-auth-k8s-abcdef1234567890-abcdef` |

---

## 🚀 How to Run

### Local Deployment
```bash
# 1. Export AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="ap-southeast-1"

# 2. Export variables (as TF_VAR_<name>)
export TF_VAR_database_url="postgresql://..."
export TF_VAR_tailscale_authkey="tskey-auth-..."

# 3. Deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Connect to EKS Cluster
```bash
aws eks update-kubeconfig --region ap-southeast-1 --name tikto-prod-eks
kubectl get nodes
```
