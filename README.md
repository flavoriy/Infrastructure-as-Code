# Infrastructure as Code - AWS DevOps Lab

Terraform code for an AWS DevOps lab with Jenkins, a single-node k3s dev cluster, and a 2-node k3s prod cluster.

State is stored in S3 and locked with DynamoDB. GitHub Actions is used for plan checks, first-time apply, destroy, and EC2 power control.

## Topology

```
+--------------------------------------------------------------------------------+
| AWS Region: ap-southeast-1                                                     |
|                                                                                |
| +----------------------------- VPC: 10.0.0.0/16 -----------------------------+ |
| |                                                                            | |
| | +---------------------- Public Subnet: 10.0.1.0/24 ----------------------+ | |
| | |                                                                        | | |
| | |  +----------------------+        +----------------------+              | | |
| | |  | Jenkins Server       |        | Jenkins Agent        |              | | |
| | |  | 10.0.1.10            |        | 10.0.1.11            |              | | |
| | |  | t2.small             |        | t2.micro             |              | | |
| | |  | 22, 8080             |        | 22                   |              | | |
| | |  +----------------------+        +----------------------+              | | |
| | |                                                                        | | |
| | |  +----------------------+                                              | | |
| | |  | k3s Dev              |                                              | | |
| | |  | 10.0.1.12            |                                              | | |
| | |  | t2.small             |                                              | | |
| | |  | 22, 6443, 30080,     |                                              | | |
| | |  | 30443                |                                              | | |
| | |  +----------------------+                                              | | |
| | |                                                                        | | |
| | |  +----------------------+        +----------------------+              | | |
| | |  | k3s Prod Master      |        | k3s Prod Worker      |              | | |
| | |  | 10.0.1.13            |        | 10.0.1.14            |              | | |
| | |  | t2.medium            |        | t2.medium            |              | | |
| | |  | Public: 22, 6443,    |        | Public: 22, 6443,    |              | | |
| | |  | 30080, 30443         |        | 30080, 30443         |              | | |
| | |  | Private: TCP 2379,   |        | Private: TCP 2379,   |              | | |
| | |  | 2380, 10250; UDP     |        | 2380, 10250; UDP     |              | | |
| | |  | 8472                 |        | 8472                 |              | | |
| | |  +----------------------+        +----------------------+              | | |
| | |                                                                        | | |
| | +------------------------------------------------------------------------+ | |
| |                                                                            | |
| | Route Table: 0.0.0.0/0 -> Internet Gateway                                 | |
| +----------------------------------------------------------------------------+ |
|                                                                                |
| Internet Gateway -> Internet                                                   |
+--------------------------------------------------------------------------------+
```

| Module | Instance type | vCPU | Private IP | Public ingress | Private ingress |
|--------|---------------|------|------------|----------------|-----------------|
| `jenkins_server` | `t2.small` | 1 | `10.0.1.10` | `22`, `8080` | - |
| `jenkins_agent` | `t2.micro` | 1 | `10.0.1.11` | `22` | - |
| `k3s_dev` | `t2.small` | 1 | `10.0.1.12` | `22`, `6443`, `30080`, `30443` | - |
| `k3s_prod_master` | `t2.medium` | 2 | `10.0.1.13` | `22`, `6443`, `30080`, `30443` | TCP `2379`, `2380`, `10250`; UDP `8472` |
| `k3s_prod_worker` | `t2.medium` | 2 | `10.0.1.14` | `22`, `6443`, `30080`, `30443` | TCP `2379`, `2380`, `10250`; UDP `8472` |

The topology uses 7 project vCPUs. It fits inside an 8 vCPU EC2 On-Demand Standard quota if no other matching instances are already running in the region.

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

## Initial Provision

Run Terraform only for the first provision, or when you intentionally accept infrastructure changes. Do not use `terraform apply` to start or stop EC2 instances after they already exist.

Before applying, verify that the selected backend state is correct:

```bash
terraform init
terraform state list
```

If `terraform state list` is empty but the EC2 instances already exist in AWS, stop. The backend/key is not pointing at the state that owns those resources, or the resources need to be imported. Running `terraform apply` in that condition can create duplicate EC2 instances.

Provision flow:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
terraform output
```

## GitHub Actions

### Terraform Infra

Workflow file: `.github/workflows/terraform.yml`

This workflow is for safe Terraform review, first-time apply, and full teardown. Start/stop is handled by the separate `EC2 Power State` workflow.

Triggers:

| Trigger | Behavior |
|---------|----------|
| Pull request to `main` | Runs init, fmt check, Checkov, Terraform plan, then blocks EC2 lifecycle changes |
| Push to `main` | Runs init, fmt check, Checkov, Terraform plan, then blocks EC2 lifecycle changes |
| Manual dispatch `apply` | Runs init, fmt check, Checkov, Terraform plan, EC2 lifecycle guard, then applies |
| Manual dispatch `destroy` | Runs init, then destroys Terraform-managed infrastructure |

The EC2 guard reads `tfplan` as JSON. It allows the first EC2 creation when Terraform state has no EC2 instances. After EC2 instances exist in state, it fails the workflow if any `aws_instance` would be created, updated, deleted, or replaced, unless the manual override `allow_ec2_lifecycle_changes=true` is selected.

Allowed through this workflow:

| Operation | Allowed |
|-----------|---------|
| Review Terraform plan | Yes |
| Create EC2 during first provision | Yes |
| Destroy all Terraform-managed infrastructure | Yes, manual `destroy` only |
| Create EC2 after initial setup | No, unless explicitly overridden |
| Update EC2 after initial setup | No, unless explicitly overridden |
| Replace EC2 after initial setup | No, unless explicitly overridden |
| Start/stop EC2 | No, use `EC2 Power State` |

Manual first apply:

1. Open GitHub Actions.
2. Select `Terraform Infra`.
3. Select `Run workflow`.
4. Choose `apply`.
5. Keep `allow_ec2_lifecycle_changes=false` for the first provision.

Manual destroy:

1. Open GitHub Actions.
2. Select `Terraform Infra`.
3. Select `Run workflow`.
4. Choose `destroy`.

### EC2 Power State

Workflow file: `.github/workflows/ec2-power-state.yml`

This workflow starts or stops existing EC2 instances by their `Name` tags. It uses AWS CLI only and does not run Terraform.

Target EC2 names:

```text
<project_name>-jenkins_server
<project_name>-jenkins_agent
<project_name>-k3s_dev
<project_name>-k3s_prod_master
<project_name>-k3s_prod_worker
```

Inputs:

| Input | Example value | Description |
|-------|---------------|-------------|
| `action` | `stop` | `start` or `stop` |
| `project_name` | `jenkins-share-lib-project` | Prefix used in the EC2 `Name` tag |

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
