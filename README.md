# Infrastructure as Code - AWS DevOps Lab

Terraform code for an AWS DevOps lab with Jenkins, a single-node k3s dev cluster, and a 3-node k3s prod server cluster.

State is stored in S3 and locked with DynamoDB. GitHub Actions is used for Terraform plan checks, manual apply/destroy, and EC2 power control.

## Operating Model

Store this repository in Git and use GitHub Actions as the control plane:

| Need | Workflow | What it does | What it does not do |
|------|----------|--------------|---------------------|
| Review Terraform changes | `Terraform Infra` on pull request or push | Runs init, format check, Checkov, plan, and EC2 lifecycle guard | Does not apply changes |
| Create infrastructure | `Terraform Infra` manual `apply` | Creates the VPC, dev/prod subnets, security groups, EIPs, and EC2 instances from Terraform | Does not configure Jenkins/k3s software by itself |
| Remove infrastructure | `Terraform Infra` manual `destroy` | Destroys Terraform-managed AWS resources | Does not preserve EC2 disks or instance state |
| Stop cost temporarily | `EC2 Power State` manual `stop` | Calls AWS CLI `stop-instances` for the existing tagged EC2 instances | Does not run Terraform and does not recreate instances |
| Start existing machines | `EC2 Power State` manual `start` | Calls AWS CLI `start-instances` for the existing tagged EC2 instances | Does not run Terraform and does not create new instances |

Use Terraform `apply` only when you want Terraform to create or intentionally change infrastructure. Use Terraform `destroy` when the lab is no longer needed and should be removed. Use the EC2 power workflow only for day-to-day start/stop of existing instances.

## Topology

```
+--------------------------------------------------------------------------------+
| AWS Region: ap-southeast-1                                                     |
|                                                                                |
| +----------------------------- VPC: 10.0.0.0/16 -----------------------------+ |
| |                                                                            | |
| | +------------- Dev Public Subnet: 10.0.1.0/24 (ap-southeast-1a) --------+ | |
| | |                                                                        | | |
| | |  +----------------------+        +----------------------+              | | |
| | |  | jenkins_server       |        | jenkins_agent        |              | | |
| | |  | 10.0.1.10 + EIP      |        | 10.0.1.11 + EIP      |              | | |
| | |  | t2.small / 15 GB     |        | t2.micro / 10 GB     |              | | |
| | |  | Public TCP: 22,8080  |        | Public TCP: 22       |              | | |
| | |  +----------------------+        +----------------------+              | | |
| | |                                                                        | | |
| | |  +----------------------+                                              | | |
| | |  | k3s_dev              |                                              | | |
| | |  | 10.0.1.12 + EIP      |                                              | | |
| | |  | t2.small / 15 GB     |                                              | | |
| | |  | Public TCP: 22,6443, |                                              | | |
| | |  | 30080,30443          |                                              | | |
| | |  +----------------------+                                              | | |
| | |                                                                        | | |
| | +------------------------------------------------------------------------+ | |
| |                                                                            | |
| | +------------ Prod Public Subnet: 10.0.2.0/24 (ap-southeast-1b) --------+ | |
| | |                                                                        | | |
| | |  +----------------------+        +----------------------+              | | |
| | |  | k3s_prod_server_1    |        | k3s_prod_server_2    |              | | |
| | |  | 10.0.2.10 + EIP      |        | 10.0.2.11 + EIP      |              | | |
| | |  | t3a.medium / 20 GB   |        | t3a.medium / 20 GB   |              | | |
| | |  | Public TCP: 22,6443, |        | Public TCP: 22,6443, |              | | |
| | |  | 30080,30443          |        | 30080,30443          |              | | |
| | |  | Private from prod:   |        | Private from prod:   |              | | |
| | |  | TCP 6443,2379,2380,  |        | TCP 6443,2379,2380,  |              | | |
| | |  | 10250; UDP 8472      |        | 10250; UDP 8472      |              | | |
| | |  +----------------------+        +----------------------+              | | |
| | |                                                                        | | |
| | |  +----------------------+                                              | | |
| | |  | k3s_prod_server_3    |                                              | | |
| | |  | 10.0.2.12 + EIP      |                                              | | |
| | |  | t3a.medium / 20 GB   |                                              | | |
| | |  | Public TCP: 22,6443, |                                              | | |
| | |  | 30080,30443          |                                              | | |
| | |  | Private from prod:   |                                              | | |
| | |  | TCP 6443,2379,2380,  |                                              | | |
| | |  | 10250; UDP 8472      |                                              | | |
| | |  +----------------------+                                              | | |
| | |                                                                        | | |
| | +------------------------------------------------------------------------+ | |
| |                                                                            | |
| | Shared route table: 0.0.0.0/0 -> Internet Gateway                          | |
| +----------------------------------------------------------------------------+ |
|                                                                                |
| Internet Gateway -> Internet                                                   |
+--------------------------------------------------------------------------------+
```

| Module | Subnet / AZ | Instance type | vCPU | Root disk | Private IP | Public IP | Public ingress | Private ingress |
|--------|-------------|---------------|------|-----------|------------|-----------|----------------|-----------------|
| `jenkins_server` | Dev `10.0.1.0/24` / `ap-southeast-1a` | `t2.small` | 1 | 15 GB | `10.0.1.10` | EIP | TCP `22`, `8080` | - |
| `jenkins_agent` | Dev `10.0.1.0/24` / `ap-southeast-1a` | `t2.micro` | 1 | 10 GB | `10.0.1.11` | EIP | TCP `22` | - |
| `k3s_dev` | Dev `10.0.1.0/24` / `ap-southeast-1a` | `t2.small` | 1 | 15 GB | `10.0.1.12` | EIP | TCP `22`, `6443`, `30080`, `30443` | - |
| `k3s_prod_server_1` | Prod `10.0.2.0/24` / `ap-southeast-1b` | `t3a.medium` | 2 | 20 GB | `10.0.2.10` | EIP | TCP `22`, `6443`, `30080`, `30443` | From `10.0.2.0/24`: TCP `6443`, `2379`, `2380`, `10250`; UDP `8472` |
| `k3s_prod_server_2` | Prod `10.0.2.0/24` / `ap-southeast-1b` | `t3a.medium` | 2 | 20 GB | `10.0.2.11` | EIP | TCP `22`, `6443`, `30080`, `30443` | From `10.0.2.0/24`: TCP `6443`, `2379`, `2380`, `10250`; UDP `8472` |
| `k3s_prod_server_3` | Prod `10.0.2.0/24` / `ap-southeast-1b` | `t3a.medium` | 2 | 20 GB | `10.0.2.12` | EIP | TCP `22`, `6443`, `30080`, `30443` | From `10.0.2.0/24`: TCP `6443`, `2379`, `2380`, `10250`; UDP `8472` |

The topology uses 9 project vCPUs when every EC2 instance is running. Request at least a 9 vCPU EC2 On-Demand Standard quota in `ap-southeast-1`, or stop nonessential lab instances before creating the full prod cluster.

Terraform provisions the AWS layer only: VPC, dev/prod subnets, shared public route table, security groups, Elastic IPs, and EC2 instances. The subnets are public because they route to the Internet Gateway; EC2 public addresses come from explicit Elastic IPs, not subnet auto-assign public IP. Jenkins, Docker, k3s, and Argo CD are configured afterward with the scripts in `scripts/`.

Prod k3s uses three server nodes with embedded etcd quorum. This can tolerate one k3s server failure at the cluster level. The prod subnet is still a single-AZ public subnet, so this is node-level HA rather than full multi-AZ HA.

Cost profile:

- Region is Singapore: `ap-southeast-1`.
- Prod k3s nodes use three `t3a.medium` instances to keep 4 GiB RAM per server node at lower cost than `t2.medium`.
- Jenkins and dev nodes stay on `t2` sizes so only the prod side grows for HA.
- CPU credits use `standard` mode to avoid unlimited burst charges.
- EC2 detailed monitoring is disabled by default for the lab budget.

## Repository

```
IaC/
|-- main.tf
|-- variables.tf
|-- outputs.tf
|-- terraform.tfvars
|-- module/
|   |-- vpc/
|   `-- ec2/
|-- scripts/
|   |-- common/
|   |-- jenkins/
|   `-- k3s/
`-- .github/workflows/
    |-- terraform.yml
    `-- ec2-power-state.yml
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

Allowed through this workflow:

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

This workflow starts or stops existing EC2 instances by their `Name` tags. It checks out the repository, reads `project_name` from `terraform.tfvars`, then uses AWS CLI only. It does not run Terraform.

It does not create, update, replace, or destroy instances. It only changes the EC2 power state for instances that already exist and match the expected `Name` tags.

Target EC2 names:

```text
<project_name>-jenkins_server
<project_name>-jenkins_agent
<project_name>-k3s_dev
<project_name>-k3s_prod_server_1
<project_name>-k3s_prod_server_2
<project_name>-k3s_prod_server_3
```

Inputs:

| Input | Example value | Description |
|-------|---------------|-------------|
| `action` | `stop` | `start` or `stop` |

The EC2 `Name` tag prefix is not entered manually. It is read from `project_name` in `terraform.tfvars`.

Behavior:

| Action | AWS state filter | AWS CLI command |
|--------|------------------|-----------------|
| `start` | `stopped` | `aws ec2 start-instances` |
| `stop` | `running` | `aws ec2 stop-instances` |

If no instances match the requested state, the workflow exits successfully without changing anything.

## GitHub Secrets

Configure these in `Settings -> Secrets and variables -> Actions`:

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

Useful endpoints:

| Service | Output |
|---------|--------|
| Jenkins UI | `http://$(terraform output -raw jenkins_server_public_ip):8080` |
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
