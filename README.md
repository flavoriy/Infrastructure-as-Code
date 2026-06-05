# Infrastructure as Code 

Terraform code to provision the AWS infrastructure for a DevOps pipeline including Jenkins, SonarQube, and Kubernetes (k3s).

## Architecture

```
ap-southeast-1a
┌─────────────────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                                  │
│  ┌───────────────────────────────────────────────┐  │
│  │  Public Subnet (10.0.1.0/24)                  │  │
│  │                                               │  │
│  │  ┌─────────────┐   ┌─────────────┐            │  │
│  │  │Jenkins      │   │Jenkins      │            │  │
│  │  │Server       │   │Agent        │            │  │
│  │  │:8080        │   │             │            │  │
│  │  └─────────────┘   └─────────────┘            │  │
│  │                                               │  │
│  │  ┌─────────────┐   ┌─────────────┐            │  │
│  │  │SonarQube    │   │k3s          │            │  │
│  │  │Server       │   │(Kubernetes) │            │  │
│  │  │:9000        │   │:6443        │            │  │
│  │  └─────────────┘   └─────────────┘            │  │
│  └───────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────┘
                           │
                   Internet Gateway
                           │
                        Internet
```

Each EC2 instance has its own dedicated **Elastic IP** and **Security Group**.

## Infrastructure Components

| Resource | Description |
|----------|-------------|
| VPC | `10.0.0.0/16`, 1 public subnet |
| Internet Gateway | Connects the subnet to the internet |
| Route Table | Routes `0.0.0.0/0` → IGW |
| EC2 × 4 | `m7i.large`, Ubuntu, EBS `gp3`, IMDSv2, encrypted volumes |
| Elastic IP × 4 | Static public IP per instance |
| Security Group × 4 | Dedicated SG per instance |

### EC2 Instances & Open Ports

| Instance | Private IP | Open Ports |
|----------|-----------|------------|
| `jenkins_server` | `10.0.1.1` | 22, 8080 |
| `jenkins_agent` | `10.0.1.2` | 22 |
| `sonarqube_server` | `10.0.1.3` | 22, 9000 |
| `k3s` | `10.0.1.4` | 22, 6443 |

## Project Structure

```
IaC/
├── main.tf                  # Root module — calls vpc and ec2 modules
├── variables.tf             # All variable declarations
├── outputs.tf               # Outputs: VPC ID, public IPs
├── terraform.tfvars         # Variable values (do not commit secrets)
├── module/
│   ├── vpc/
│   │   ├── main.tf          # VPC, Subnet, IGW, Route Table
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ec2/
│       ├── main.tf          # Security Group, EIP, EC2, EIP Association
│       ├── variables.tf
│       └── outputs.tf
└── .github/
    └── workflows/
        └── terraform.yml    # CI/CD pipeline
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- AWS account with permissions: `AmazonEC2FullAccess`, `AmazonVPCFullAccess`
- AWS CLI configured with credentials (`aws configure`)
- An SSH key pair created in the `ap-southeast-1` region

## Quick Start

### 1. Clone and configure variables

```bash
git clone <repo-url>
cd IaC
```

Edit `terraform.tfvars`:
```hcl
aim_id       = "ami-xxxxxxxxxxxxxxxxx"   # Ubuntu AMI in ap-southeast-1
project_name = "devops-project"
key_name     = "your-key-pair-name"
```

### 2. Run Terraform

```bash
terraform init
terraform plan
terraform apply
```

### 3. Get public IPs after apply

```bash
terraform output
```

### 4. Stop / Start instances (cost saving)

In `terraform.tfvars`:
```hcl
instance_state = "stopped"   # stop all instances
instance_state = "running"   # start all instances
```

Then run `terraform apply`.

### 5. Destroy all infrastructure

```bash
terraform destroy
```

## CI/CD Pipeline (GitHub Actions)

The pipeline runs automatically on every push or pull request to the `main` branch.

```
push/PR → Checkout → AWS Auth → Terraform Init → fmt check → Checkov Scan → Terraform Plan
```

### GitHub Secrets Configuration

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | AWS IAM Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM Secret Access Key |
| `AWS_REGION` | `ap-southeast-1` |

### Checkov Security Scan

The pipeline scans for security issues using [Checkov](https://www.checkov.io/) and fails on any `HIGH` or `CRITICAL` findings.

The following checks are intentionally skipped:

| Check ID | Reason |
|----------|--------|
| `CKV_AWS_382` | Open egress required for package and image downloads |
| `CKV2_AWS_11` | VPC Flow Logs not required for a lab environment |
| `CKV2_AWS_41` | IAM instance profile not required for a lab environment |

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | string | `ap-southeast-1` | AWS region to deploy resources |
| `cidr_block` | string | `10.0.0.0/16` | VPC CIDR block |
| `subnet_cidr` | string | `10.0.1.0/24` | Public subnet CIDR block |
| `subnet_ip` | list(string) | `[10.0.1.1–1.4]` | Private IPs for the 4 instances |
| `aim_id` | string | — | AMI ID (required) |
| `project_name` | string | — | Project name, used for all resource tags |
| `key_name` | string | `jenkins-share-lib.pem` | SSH key pair name |
| `instance_state` | string | `running` | `running` or `stopped` |

## Outputs

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC ID |
| `jenkins_server_public_ip` | Public IP of the Jenkins Server |
| `jenkins_agent_public_ip` | Public IP of the Jenkins Agent |
| `sonar_server_public_ip` | Public IP of SonarQube |
| `k3s_public_ip` | Public IP of k3s |
