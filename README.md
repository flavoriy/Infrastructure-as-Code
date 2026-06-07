# Infrastructure as Code — AWS DevOps Lab

Terraform code to provision AWS infrastructure for a DevOps pipeline (Jenkins and a 3-node k3s cluster). State is stored in S3 and managed via GitHub Actions.

## Architecture

```
+----------------------------------------------------------------------------+
| AWS Region: ap-southeast-1                                                 |
|                                                                            |
| +--------------------------- VPC: 10.0.0.0/16 ---------------------------+ |
| |                                                                        | |
| | +-------------------- Public Subnet: 10.0.1.0/24 --------------------+ | |
| | |                                                                    | | |
| | |  +----------------------+      +----------------------+            | | |
| | |  | Jenkins Server       |      | Jenkins Agent        |            | | |
| | |  | IP: 10.0.1.10        |      | IP: 10.0.1.11        |            | | |
| | |  | Ports: 22, 8080      |      | Ports: 22            |            | | |
| | |  | EIP                  |      | EIP                  |            | | |
| | |  +----------------------+      +----------------------+            | | |
| | |                                                                    | | |
| | |  +----------------------+      +----------------------+            | | |
| | |  | k3s Worker 1         |      | k3s Control Plane    |            | | |
| | |  | IP: 10.0.1.12        |      | IP: 10.0.1.13        |            | | |
| | |  | Ports: 22, 30080,    |      | Ports: 22, 6443,     |            | | |
| | |  |        30443         |      |        30080, 30443  |            | | |
| | |  | EIP                  |      | EIP                  |            | | |
| | |  +----------------------+      +----------------------+            | | |
| | |                                                                    | | |
| | |  +----------------------+                                          | | |
| | |  | k3s Worker 2         |                                          | | |
| | |  | IP: 10.0.1.14        |                                          | | |
| | |  | Ports: 22, 30080,    |                                          | | |
| | |  |        30443         |                                          | | |
| | |  | EIP                  |                                          | | |
| | |  +----------------------+                                          | | |
| | |                                                                    | | |
| | +--------------------------------------------------------------------+ | |
| |                                                                        | |
| | Route Table: 0.0.0.0/0 -> Internet Gateway                             | |
| +------------------------------------------------------------------------+ |
|                                                                            |
| Internet Gateway -> Internet                                               |
+----------------------------------------------------------------------------+
```

**Each instance:** `m7i-flex.large` (2 vCPU · 8 GB RAM) · EBS gp3 encrypted · IMDSv2 · Dedicated Security Group · Static Elastic IP

## Project Structure

```
IaC/
├── main.tf              # S3 backend + module calls
├── variables.tf
├── outputs.tf
├── terraform.tfvars     # ← edit this (do not commit secrets)
├── module/
│   ├── vpc/             # VPC, Subnet, IGW, Route Table
│   └── ec2/             # SG, EIP, EC2
└── .github/workflows/
    ├── terraform.yml        # create/update/destroy infrastructure
    └── ec2-power-state.yml  # start/stop existing EC2 instances
```

## Setup (one-time)

### 1. Create S3 backend resources

```bash
BUCKET="bucket-project-devops-tfstate"   # must be globally unique
REGION="ap-southeast-1"

aws s3api create-bucket --bucket $BUCKET --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION
aws s3api put-bucket-versioning --bucket $BUCKET \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket $BUCKET \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
aws dynamodb create-table --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region $REGION
```

### 2. Add GitHub Secrets

**Settings → Secrets and variables → Actions:**

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM Access Key |
| `AWS_SECRET_ACCESS_KEY` | IAM Secret Key |
| `AWS_REGION` | `ap-southeast-1` |

The IAM user needs: `AmazonEC2FullAccess`, `AmazonVPCFullAccess`, and S3/DynamoDB access to the backend bucket.

### 3. Configure terraform.tfvars

```hcl
aim_id       = "ami-xxxxxxxxxxxxxxxxx"   # Ubuntu 22.04 in ap-southeast-1
project_name = "devops-project"
key_name     = "your-key-pair-name"
```

Find the latest Ubuntu 22.04 AMI:
```bash
aws ec2 describe-images --owners 099720109477 --region ap-southeast-1 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" --output text
```

## CI/CD Pipeline

| Trigger | What runs |
|---------|-----------|
| Pull Request → `main` | Init → fmt → Checkov → Plan |
| Push → `main` | Init → fmt → Checkov → Plan |
| Manual `apply` | → Plan → **Apply infra changes** |
| Manual `destroy` | → **Destroy infra** |
| Manual `EC2 Power State` `start` | Start existing EC2 instances by `Name` tag |
| Manual `EC2 Power State` `stop` | Stop existing EC2 instances by `Name` tag |

**Infra trigger:** Actions → Terraform Infra → Run workflow → choose action.
By default, the infra workflow blocks EC2 replacement. Use `allow_instance_replace=true` only when you intentionally want to recreate EC2 instances.

**EC2 power trigger:** Actions → EC2 Power State → Run workflow → choose `start` or `stop`.
This workflow uses AWS CLI only. It does not run `terraform apply`, so it cannot recreate instances.

## How S3 State Works

```
terraform init   → downloads state from S3 (knows what already exists)
terraform plan   → diffs state vs code → shows only what changes
terraform apply  → applies changes → uploads new state to S3
```

DynamoDB prevents two workflows from running apply simultaneously (state locking).

## Common Errors

| Error | Fix |
|-------|-----|
| `NoSuchBucket` | Run the S3 setup commands above |
| `VpcLimitExceeded` | Delete unused VPCs in Console → VPC |
| `AddressLimitExceeded` | Release unassociated EIPs in Console → EC2 → Elastic IPs |
| `reserved address range` | Subnet IPs must be ≥ `10.0.1.4` (first 4 are reserved by AWS) |
| `couldn't find resource` | AMI ID is wrong for this region — use the CLI command above |
