# TikTo AWS Infrastructure (IaC)

Modular Terraform setup to deploy the AWS cloud infrastructure for the **TikTo** platform (VPC, EC2, EKS, OpenSearch, and Secrets Manager).

---

## 🗺️ System Topology

This diagram shows how public users access the app via the Load Balancer, and how developers connect securely to the private subnet via Tailscale VPN.

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

## 📂 Project Structure

Here is how the repository is organized:

```text
.
├── module/                 # Reusable infrastructure modules
│   ├── vpc/                # Multi-AZ VPC networking
│   ├── ec2/                # Standalone EC2 instances (Argo CD & K3s Dev)
│   ├── eks/                # EKS Cluster & Spot Node Group (Prod)
│   ├── opensearch/         # OpenSearch logging cluster (Prod)
│   └── secrets_manager/    # AWS Secrets Manager module
├── scripts/                # Node bootstrap and initialization scripts
│   ├── common/             # Base OS package setup
│   ├── k3s/                # Local k3s and Argo CD configuration
│   └── nodes/              # Node setup scripts (Argo CD & K3s Dev)
├── main.tf                 # Orchestration of all modules
├── variables.tf            # Input variable declarations
├── outputs.tf              # Endpoints and metadata outputs
├── secrets_and_iam.tf      # Secrets Manager stores & IAM policy configurations
└── terraform.tfvars        # Default configuration values
```

---

## 🛠️ Prerequisites & GitHub Secrets

Before running the deployment, configure these secrets in your GitHub repository under the `production` environment:

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

---

## 🚀 How to Run

### Deploy Locally
To deploy from your local CLI, export your credentials and run the commands:

```bash
# 1. AWS Credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-southeast-1"

# 2. Export variables (e.g.)
export TF_VAR_database_url="postgresql://..."
export TF_VAR_tailscale_authkey="tskey-auth-..."

# 3. Apply
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Connect to the EKS Cluster
Once provisioning is done, update your local kubeconfig:
```bash
aws eks update-kubeconfig --region ap-southeast-1 --name tikto-prod-eks
kubectl get nodes
```

---

## 💡 Key Design Notes
*   **Cost Optimization**: Production EKS uses Spot Instances (`t3.medium`, `t3a.medium`, `t2.medium`), cutting cluster compute costs by **70%**.
*   **Secure Access**: No public ports are exposed for administration. Argo CD, K3s APIs, and Kibana logs are only reachable after logging into the VPC via Tailscale VPN.
*   **Encrypted Secrets**: App secrets are pushed dynamically from GitHub Secrets to AWS Secrets Manager using variables, avoiding hardcoding keys in Git.
