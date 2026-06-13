# Infrastructure as Code - AWS DevOps Lab

Terraform code for an AWS DevOps lab with a single-node k3s dev cluster and a 3-node k3s prod HA cluster.

State is stored in S3 and locked with DynamoDB. GitHub Actions is used for Terraform plan checks, manual apply/destroy, and EC2 power control.

## Operating Model

Store this repository in Git and use GitHub Actions as the control plane:

| Need | Workflow | What it does | What it does not do |
|------|----------|--------------|---------------------|
| Review Terraform changes | `Terraform Infra` on pull request or push | Runs init, format check, Checkov, plan, and EC2 lifecycle guard | Does not apply changes |
| Create infrastructure | `Terraform Infra` manual `apply` | Creates the VPC, subnets, security groups, EIPs, and EC2 instances | Does not configure k3s software by itself |
| Remove infrastructure | `Terraform Infra` manual `destroy` | Destroys Terraform-managed AWS resources | Does not preserve EC2 disks or instance state |
| Stop cost temporarily | `EC2 Power State` manual `stop` | Calls AWS CLI `stop-instances` for existing tagged EC2 instances | Does not run Terraform and does not recreate instances |
| Start existing machines | `EC2 Power State` manual `start` | Calls AWS CLI `start-instances` for existing tagged EC2 instances | Does not run Terraform and does not create new instances |

Use Terraform `apply` only when you want Terraform to create or intentionally change infrastructure. Use Terraform `destroy` when the lab is no longer needed and should be removed. Use the EC2 power workflow only for day-to-day start/stop of existing instances.

## Topology

```
+--------------------------------------------------------------------------------+
| AWS Region: ap-southeast-1                                                     |
|                                                                                |
| +----------------------------- VPC: 10.0.0.0/16 -----------------------------+ |
| |                                                                            | |
| | +----------------- Dev Subnet: 10.0.1.0/24 (ap-southeast-1a) ------------+ | |
| | |                                                                        | | |
| | |  +----------------------+                                              | | |
| | |  | k3s_dev              |                                              | | |
| | |  | 10.0.1.12 + EIP      |                                              | | |
| | |  | AZ: ap-southeast-1a  |                                              | | |
| | |  | t2.small / 15 GB     |                                              | | |
| | |  | Public: 30080, 30443 |                                              | | |
| | |  | Admin: 22, 6443      |                                              | | |
| | |  | (restricted)         |                                              | | |
| | |  +----------------------+                                              | | |
| | |                                                                        | | |
| | +------------------------------------------------------------------------+ | |
| |                                                                            | |
| | +----------------- Prod Subnet 1: 10.0.2.0/24 (ap-southeast-1a) ---------+ | |
| | |                                                                        | | |
| | |  +----------------------+                                              | | |
| | |  | k3s_prod_server_1    |                                              | | |
| | |  | 10.0.2.10 + EIP      |                                              | | |
| | |  | AZ: ap-southeast-1a  |                                              | | |
| | |  | t3a.medium / 20 GB   |                                              | | |
| | |  | Public: 30080, 30443 |                                              | | |
| | |  | Admin: 22, 6443      |                                              | | |
| | |  | (restricted)         |                                              | | |
| | |  | Private: TCP 6443,   |                                              | | |
| | |  |   2379, 2380, 10250; |                                              | | |
| | |  |   UDP 8472           |                                              | | |
| | |  +----------------------+                                              | | |
| | |                                                                        | | |
| | +------------------------------------------------------------------------+ | |
| |                                                                            | |
| | +----------------- Prod Subnet 2: 10.0.3.0/24 (ap-southeast-1b) ---------+ | |
| | |                                                                        | | |
| | |  +----------------------+                                              | | |
| | |  | k3s_prod_server_2    |                                              | | |
| | |  | 10.0.3.10 + EIP      |                                              | | |
| | |  | AZ: ap-southeast-1b  |                                              | | |
| | |  | t3a.medium / 20 GB   |                                              | | |
| | |  | Public: 30080, 30443 |                                              | | |
| | |  | Admin: 22, 6443      |                                              | | |
| | |  | (restricted)         |                                              | | |
| | |  | Private: TCP 6443,   |                                              | | |
| | |  |   2379, 2380, 10250; |                                              | | |
| | |  |   UDP 8472           |                                              | | |
| | |  +----------------------+                                              | | |
| | |                                                                        | | |
| | +------------------------------------------------------------------------+ | |
| |                                                                            | |
| | +----------------- Prod Subnet 3: 10.0.4.0/24 (ap-southeast-1c) ---------+ | |
| | |                                                                        | | |
| | |  +----------------------+                                              | | |
| | |  | k3s_prod_server_3    |                                              | | |
| | |  | 10.0.4.10 + EIP      |                                              | | |
| | |  | AZ: ap-southeast-1c  |                                              | | |
| | |  | t3a.medium / 20 GB   |                                              | | |
| | |  | Public: 30080, 30443 |                                              | | |
| | |  | Admin: 22, 6443      |                                              | | |
| | |  | (restricted)         |                                              | | |
| | |  | Private: TCP 6443,   |                                              | | |
| | |  |   2379, 2380, 10250; |                                              | | |
| | |  |   UDP 8472           |                                              | | |
| | |  +----------------------+                                              | | |
| | |                                                                        | | |
| | +------------------------------------------------------------------------+ | |
| |                                                                            | |
| | Route Table: 0.0.0.0/0 -> Internet Gateway                                 | |
| +----------------------------------------------------------------------------+ |
|                                                                                |
| Internet Gateway -> Internet                                                   |
+--------------------------------------------------------------------------------+
```

| Module | Subnet / AZ | Type | vCPU | RAM | Disk | Private IP | Public IP | Public ingress | Private ingress |
|--------|-------------|------|------|-----|------|------------|-----------|----------------|-----------------|
| `k3s_dev` | Dev / `1a` | `t2.small` | 1 | 2 GiB | 15 GB | `10.0.1.12` | EIP | TCP `30080`, `30443`; TCP `22`, `6443` (restricted) | — |
| `k3s_prod_server_1` | Prod 1 / `1a` | `t3a.medium` | 2 | 4 GiB | 20 GB | `10.0.2.10` | EIP | TCP `30080`, `30443`; TCP `22`, `6443` (restricted) | TCP `6443`, `2379`, `2380`, `10250`; UDP `8472` |
| `k3s_prod_server_2` | Prod 2 / `1b` | `t3a.medium` | 2 | 4 GiB | 20 GB | `10.0.3.10` | EIP | TCP `30080`, `30443`; TCP `22`, `6443` (restricted) | TCP `6443`, `2379`, `2380`, `10250`; UDP `8472` |
| `k3s_prod_server_3` | Prod 3 / `1c` | `t3a.medium` | 2 | 4 GiB | 20 GB | `10.0.4.10` | EIP | TCP `30080`, `30443`; TCP `22`, `6443` (restricted) | TCP `6443`, `2379`, `2380`, `10250`; UDP `8472` |

Total: 4 instances, 7 vCPUs, 75 GB EBS.

Terraform provisions the AWS layer only: VPC, subnets, route table, security groups, Elastic IPs, and EC2 instances. The subnets are public (route to IGW); EC2 public addresses come from explicit Elastic IPs, not subnet auto-assign. k3s and Argo CD are configured afterward with the scripts in `scripts/`.

Prod k3s uses three server nodes with embedded etcd quorum. This can tolerate one k3s server failure at the cluster level. The prod subnets are spread across three Availability Zones (ap-southeast-1a, 1b, 1c), providing full multi-AZ HA at the infrastructure level.

Cost profile:

- Region: Singapore `ap-southeast-1`.
- Prod k3s: three `t3a.medium` (4 GiB RAM each, lower cost than `t2.medium`).
- Dev k3s: `t2.small` for a lightweight single-node cluster.
- CPU credits: `standard` to avoid unlimited burst charges.
- EC2 detailed monitoring: disabled by default for lab budget.

## Repository

```
IaC/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── module/
│   ├── vpc/
│   └── ec2/
├── scripts/
│   ├── CONFIGURE.md
│   ├── common/
│   ├── k3s/
│   └── nodes/
└── .github/workflows/
    ├── terraform.yml
    └── ec2-power-state.yml
```

## Terraform Lifecycle

Run Terraform only to create, intentionally change, or destroy infrastructure. Do not use `terraform apply` to start or stop EC2 instances after they already exist.

Before applying, verify that the selected backend state is correct:

```bash
terraform init
terraform state list
```

If `terraform state list` is empty but the EC2 instances already exist in AWS, stop. The backend/key is not pointing at the state that owns those resources, or the resources need to be imported. Running `terraform apply` in that condition can create duplicate EC2 instances.

Local provision flow, equivalent to the manual `apply` workflow:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
terraform output
```

When the lab is no longer needed, use the manual `destroy` action in the `Terraform Infra` workflow or run:

```bash
terraform destroy
```

Destroy removes Terraform-managed resources, including EC2 instances and their root volumes.

## GitHub Actions

### Terraform Infra

Workflow file: `.github/workflows/terraform.yml`

This workflow is for safe Terraform review, infrastructure creation, and full teardown. Start/stop is handled by the separate `EC2 Power State` workflow.

Triggers:

| Trigger | Behavior |
|---------|----------|
| Pull request to `main` | Runs init, fmt check, Checkov, Terraform plan, then blocks EC2 lifecycle changes |
| Push to `main` | Runs init, fmt check, Checkov, Terraform plan, then blocks EC2 lifecycle changes |
| Manual dispatch `apply` | Runs init, fmt check, Checkov, Terraform plan, EC2 lifecycle guard, then applies |
| Manual dispatch `destroy` | Runs init, then destroys Terraform-managed infrastructure |

The EC2 guard reads `tfplan` as JSON. It allows initial EC2 creation when Terraform state has no EC2 instances. After EC2 instances exist in state, it fails the workflow if any `aws_instance` would be created, updated, deleted, or replaced. This prevents accidentally using Terraform as a start/stop mechanism.

| Operation | Allowed |
|-----------|---------|
| Review Terraform plan | Yes |
| Create EC2 during first provision | Yes |
| Destroy all Terraform-managed infrastructure | Yes, manual `destroy` only |
| Create EC2 after initial setup | No |
| Update EC2 after initial setup | No |
| Replace EC2 after initial setup | No |
| Start/stop EC2 | No, use `EC2 Power State` |

Manual apply:

1. Open GitHub Actions.
2. Select `Terraform Infra`.
3. Select `Run workflow`.
4. Choose `apply`.

Manual destroy:

1. Open GitHub Actions.
2. Select `Terraform Infra`.
3. Select `Run workflow`.
4. Choose `destroy`.

### EC2 Power State

Workflow file: `.github/workflows/ec2-power-state.yml`

This workflow starts or stops existing EC2 instances by their `Name` tags. It reads `project_name` from `terraform.tfvars` and uses AWS CLI only. It does not run Terraform.

Target EC2 names:

```text
<project_name>-k3s_dev
<project_name>-k3s_prod_server_1
<project_name>-k3s_prod_server_2
<project_name>-k3s_prod_server_3
```

| Input | Values | Description |
|-------|--------|-------------|
| `action` | `start` / `stop` | Power action to perform |

| Action | AWS state filter | AWS CLI command |
|--------|-----------------|-----------------|
| `start` | `stopped` | `aws ec2 start-instances` |
| `stop` | `running` | `aws ec2 stop-instances` |

If no instances match the requested state, the workflow exits successfully without changing anything.

## GitHub Secrets

Configure in `Settings -> Secrets and variables -> Actions`:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM access key |
| `AWS_SECRET_ACCESS_KEY` | IAM secret key |
| `AWS_REGION` | `ap-southeast-1` |

The IAM identity needs EC2/VPC permissions and S3/DynamoDB permissions for the Terraform backend.

## Outputs

After initial provision:

```bash
terraform output
```

| Service | Output |
|---------|--------|
| k3s dev API | `https://$(terraform output -raw k3s_dev_public_ip):6443` |
| k3s dev NodePort HTTP | `http://$(terraform output -raw k3s_dev_public_ip):30080` |
| k3s dev NodePort HTTPS | `https://$(terraform output -raw k3s_dev_public_ip):30443` |
| k3s prod public IPs | `terraform output k3s_prod_public_ips` |

## Notes

- Terraform version: `>= 1.1`
- Backend bucket: `bucket-project-devops-tfstate`
- Backend lock table: `terraform-state-lock`
- AWS region: `ap-southeast-1`
- AWS key pair: `jenkins-share-lib`
