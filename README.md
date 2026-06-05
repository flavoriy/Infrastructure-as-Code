# Infrastructure as Code

Terraform code to provision the AWS infrastructure for a DevOps pipeline including Jenkins, SonarQube, and Kubernetes (k3s). State is stored remotely in S3 and managed via GitHub Actions.

## Architecture

```
ap-southeast-1a
┌─────────────────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                                  │
│  ┌───────────────────────────────────────────────┐  │
│  │  Public Subnet (10.0.1.0/24)                  │  │
│  │                                               │  │
│  │  ┌─────────────┐   ┌─────────────┐           │  │
│  │  │Jenkins      │   │Jenkins      │           │  │
│  │  │Server       │   │Agent        │           │  │
│  │  │10.0.1.10    │   │10.0.1.11    │           │  │
│  │  │:22, :8080   │   │:22          │           │  │
│  │  └──────┬──────┘   └──────┬──────┘           │  │
│  │         │EIP              │EIP                │  │
│  │  ┌─────────────┐   ┌─────────────┐           │  │
│  │  │SonarQube    │   │k3s          │           │  │
│  │  │Server       │   │(Kubernetes) │           │  │
│  │  │10.0.1.12    │   │10.0.1.13    │           │  │
│  │  │:22, :9000   │   │:22, :6443   │           │  │
│  │  └──────┬──────┘   └──────┬──────┘           │  │
│  │         │EIP              │EIP                │  │
│  └───────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────┘
                           │
                   Internet Gateway
                           │
                        Internet
```

Each EC2 instance has its own dedicated **Elastic IP** and **Security Group**.

---

## Infrastructure Components

| Resource | Description |
|----------|-------------|
| VPC | `10.0.0.0/16`, 1 public subnet |
| Internet Gateway | Connects the subnet to the internet |
| Route Table | Routes `0.0.0.0/0` → IGW |
| Default SG | Overridden to block all traffic (security hardening) |
| EC2 × 4 | `m7i-flex.large` (2 vCPU, 8GB RAM), EBS `gp3` encrypted, IMDSv2, detailed monitoring |
| Elastic IP × 4 | Static public IP per instance |
| Security Group × 4 | Dedicated SG per instance, unique ingress rules |

### EC2 Instances & Open Ports

| Instance | Private IP | Open Ports | Role |
|----------|-----------|------------|------|
| `jenkins_server` | `10.0.1.10` | 22, 8080 | Jenkins master |
| `jenkins_agent` | `10.0.1.11` | 22 | Jenkins build agent |
| `sonarqube_server` | `10.0.1.12` | 22, 9000 | Code quality analysis |
| `k3s` | `10.0.1.13` | 22, 6443 | Lightweight Kubernetes |

---

## Project Structure

```
IaC/
├── main.tf                  # Root module — S3 backend, calls vpc and ec2 modules
├── variables.tf             # All variable declarations
├── outputs.tf               # Outputs: VPC ID, public IPs
├── terraform.tfvars         # Variable values (do not commit secrets)
├── module/
│   ├── vpc/
│   │   ├── main.tf          # VPC, Subnet, IGW, Route Table, Default SG
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ec2/
│       ├── main.tf          # Security Group, EIP, EC2, EIP Association, Instance State
│       ├── variables.tf
│       └── outputs.tf
└── .github/
    └── workflows/
        └── terraform.yml    # CI/CD pipeline
```

> GitHub only discovers workflows from `.github/workflows` at the repository root. This README assumes `IaC/` is used as the repository root. If your repository root is the parent folder, move `.github/workflows/terraform.yml` to the parent root and set the workflow working directory to `IaC`.

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- AWS account with the following IAM permissions:
  - `AmazonEC2FullAccess`
  - `AmazonVPCFullAccess`
  - S3 and DynamoDB access for remote state (see [Remote State Setup](#remote-state-setup))
- AWS CLI configured locally (`aws configure`)
- An SSH key pair already created in the `ap-southeast-1` region

---

## Remote State Setup (one-time)

Terraform state is stored in S3 so that GitHub Actions runners (which are ephemeral) can share and persist state between runs. This must be done **once before the first `terraform init`**.

### Why remote state is needed

```
Without S3 backend:                    With S3 backend:
─────────────────────────────          ─────────────────────────────
Run 1: apply → state saved locally     Run 1: apply → state saved to S3
Runner destroyed → state lost          Runner destroyed → state safe in S3
Run 2: no state → tries to             Run 2: init downloads state from S3
  recreate everything → errors           → knows what exists → only diffs
```

### Create S3 bucket and DynamoDB table

Run these commands once using the AWS CLI:

```bash
# This must match terraform.backend.s3.bucket in main.tf.
# If the name is unavailable, choose another globally unique name and update main.tf too.
BUCKET_NAME="bucket-project-devops-tfstate"
REGION="ap-southeast-1"

# 1. Create the S3 bucket
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

# 2. Enable versioning (allows rollback to previous state)
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# 3. Block all public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# 4. Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION
```

### Verify bucket name in main.tf

```hcl
backend "s3" {
  bucket         = "bucket-project-devops-tfstate"
  key            = "terraform.tfstate"
  region         = "ap-southeast-1"
  dynamodb_table = "terraform-state-lock"
  encrypt        = true
}
```

### How the workflow interacts with S3

| Step | What happens |
|------|-------------|
| `terraform init` | Downloads current state from S3 to the runner |
| `terraform plan` | Reads state → knows which resources exist → shows only the diff |
| `terraform apply` | Applies changes to AWS → uploads updated state back to S3 |
| `terraform destroy` | Deletes all resources → uploads empty state to S3 |

**State locking with DynamoDB:** When `apply` or `destroy` runs, a lock record is written to DynamoDB. If a second workflow tries to run at the same time, it sees the lock and fails immediately — preventing concurrent state corruption.

### Add S3/DynamoDB permissions to the IAM user

The IAM user used in GitHub Secrets needs access to the bucket. Attach this inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::bucket-project-devops-tfstate",
        "arn:aws:s3:::bucket-project-devops-tfstate/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:ap-southeast-1:*:table/terraform-state-lock"
    }
  ]
}
```

---

## Quick Start

### 1. Complete Remote State Setup

Follow the [Remote State Setup](#remote-state-setup) section above before proceeding.

### 2. Clone and configure variables

```bash
git clone <repo-url>
cd IaC
```

If `IaC` is already your repository root, skip `cd IaC`.

Edit `terraform.tfvars`:
```hcl
aim_id       = "ami-xxxxxxxxxxxxxxxxx"   # Ubuntu AMI in ap-southeast-1
project_name = "devops-project"
key_name     = "your-key-pair-name"      # SSH key pair name (without .pem)
```

To find the latest Ubuntu 22.04 AMI for `ap-southeast-1`:
```bash
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" \
  --region ap-southeast-1 \
  --output text
```

### 3. Push to GitHub to trigger the pipeline

```bash
git add .
git commit -m "initial infrastructure"
git push origin main
```

Push to `main` triggers: Init → fmt check → Checkov scan → Plan. No auto-apply on push for safety.

### 4. Apply infrastructure

Go to **Actions → Terraform → Run workflow → action: `apply`**.

### 5. Get public IPs after apply

```bash
terraform output
```

Or check the **Actions → Terraform → latest apply run → outputs** in the GitHub Actions log.

### 6. Stop / Start instances (cost saving)

Go to **Actions → Terraform → Run workflow**:

| action | What it does |
|--------|-------------|
| `start` | Runs `terraform apply -var="instance_state=running"` — starts all 4 instances |
| `stop` | Runs `terraform apply -var="instance_state=stopped"` — stops all 4 instances |

> **Cost note:** `m7i-flex.large` may be billable depending on your AWS account, Free Tier/Free Plan eligibility, and region. Stopping instances saves EC2 compute cost, but EBS volumes and public IPv4/EIP can still incur cost.

### 7. Destroy all infrastructure

Go to **Actions → Terraform → Run workflow → action: `destroy`**.

> This permanently deletes all resources including VPC, EC2, EIPs, and Security Groups. The S3 bucket and DynamoDB table are **not** deleted (they are created outside Terraform).

---

## CI/CD Pipeline (GitHub Actions)

### Trigger modes

| Trigger | Steps executed |
|---------|---------------|
| Pull Request → `main` | Checkout → AWS Auth → Init → fmt check → Checkov → **Plan only** |
| Push → `main` | Checkout → AWS Auth → Init → fmt check → Checkov → **Plan only** |
| Manual `apply` | Checkout → AWS Auth → Init → fmt check → Checkov → Plan → **Apply** |
| Manual `start` | Checkout → AWS Auth → Init → fmt check → Checkov → Plan(running) → **Apply(running)** |
| Manual `stop` | Checkout → AWS Auth → Init → fmt check → Checkov → Plan(stopped) → **Apply(stopped)** |
| Manual `destroy` | Checkout → AWS Auth → Init → **Destroy** (no Checkov/Plan) |

### GitHub Secrets Configuration

Go to **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | AWS IAM Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM Secret Access Key |
| `AWS_REGION` | `ap-southeast-1` |

### Checkov Security Scan

The pipeline scans for security issues using [Checkov](https://www.checkov.io/) and fails on any `HIGH` or `CRITICAL` findings. Scan is skipped automatically when `action = destroy`.

The following checks are intentionally skipped:

| Check ID | Reason |
|----------|--------|
| `CKV_AWS_382` | Open egress required for package and image downloads |
| `CKV2_AWS_11` | VPC Flow Logs not required for a lab environment |
| `CKV2_AWS_41` | IAM instance profile not required for a lab environment |

---

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | string | `ap-southeast-1` | AWS region to deploy resources |
| `cidr_block` | string | `10.0.0.0/16` | VPC CIDR block |
| `subnet_cidr` | string | `10.0.1.0/24` | Public subnet CIDR block |
| `subnet_ip` | list(string) | `[10.0.1.10–.13]` | Private IPs for the 4 instances (must avoid first 4 reserved IPs) |
| `aim_id` | string | — | AMI ID — **required**, region-specific |
| `project_name` | string | — | Project name, applied as prefix to all resource tags |
| `key_name` | string | `jenkins-share-lib` | SSH key pair name, without `.pem` |
| `instance_state` | string | `running` | `running` or `stopped` — controls EC2 start/stop |

---

## Outputs

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC ID |
| `jenkins_server_public_ip` | Public IP of the Jenkins Server |
| `jenkins_agent_public_ip` | Public IP of the Jenkins Agent |
| `sonar_server_public_ip` | Public IP of SonarQube |
| `k3s_public_ip` | Public IP of k3s |

---

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `NoSuchBucket` | S3 bucket not created yet | Run the [Remote State Setup](#remote-state-setup) steps |
| `VpcLimitExceeded` | 5 VPC limit reached | Delete unused VPCs in AWS Console → VPC |
| `AddressLimitExceeded` | 5 EIP limit reached | Release unassociated EIPs in AWS Console → EC2 → Elastic IPs |
| `InvalidParameterValue: reserved address range` | Private IP in `10.0.1.0–3` | Use IPs `10.0.1.4` or higher |
| `couldn't find resource` | AMI ID doesn't exist in this region | Use the AWS CLI command above to find the correct AMI |
| Unexpected EC2 charges | Account/region not covered by Free Tier/Free Plan, or EBS/public IPv4 still billed | Check AWS Billing and current pricing; stop instances when idle |
