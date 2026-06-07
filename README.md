# Infrastructure as Code

Terraform configuration for an AWS Jenkins and k3s lab. Terraform state is stored in an S3 backend.

## Infrastructure

Current resources:

| Resource | Details |
|----------|---------|
| VPC | `10.0.0.0/16` |
| Public subnet | `10.0.1.0/24` |
| Jenkins server | EC2 `10.0.1.10`, ports `22`, `8080` |
| Jenkins agent | EC2 `10.0.1.11`, port `22` |
| k3s control plane | EC2 `10.0.1.13`, ports `22`, `6443`, `30080`, `30443` |
| k3s worker 1 | EC2 `10.0.1.12`, ports `22`, `30080`, `30443` |
| k3s worker 2 | EC2 `10.0.1.14`, ports `22`, `30080`, `30443` |

Each EC2 instance has its own security group, Elastic IP, encrypted gp3 root volume, and IMDSv2 enabled.

## State Backend

Terraform state is stored in S3:

```hcl
bucket         = "bucket-project-devops-tfstate"
key            = "terraform.tfstate"
region         = "ap-southeast-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
```

## Workflows

### Terraform Infra

File: `.github/workflows/terraform.yml`

Use this workflow to create, update, or destroy infrastructure.

Manual options:

| Action | Result |
|--------|--------|
| `apply` | Creates or updates infrastructure |
| `destroy` | Destroys infrastructure |

Pushes and pull requests only run checks and `terraform plan`; they do not apply changes.

The workflow blocks EC2 replacement by default. If a plan wants to delete and recreate an EC2 instance, the workflow stops and prints the affected instance details.

### EC2 Power State

File: `.github/workflows/ec2-power-state.yml`

Use this workflow only to start or stop existing EC2 instances. It does not run Terraform and cannot create, recreate, or destroy infrastructure.

Manual options:

| Action | Result |
|--------|--------|
| `start` | Starts all stopped project EC2 instances |
| `stop` | Stops all running project EC2 instances |

Managed EC2 names:

```text
jenkins-share-lib-project-jenkins_server
jenkins-share-lib-project-jenkins_agent
jenkins-share-lib-project-k3s
jenkins-share-lib-project-k3s_worker_1
jenkins-share-lib-project-k3s_worker_2
```

## Usage

Create or update infrastructure:

```text
GitHub Actions -> Terraform Infra -> Run workflow -> apply
```

Destroy infrastructure:

```text
GitHub Actions -> Terraform Infra -> Run workflow -> destroy
```

Stop all EC2 instances:

```text
GitHub Actions -> EC2 Power State -> Run workflow -> stop
```

Start all EC2 instances:

```text
GitHub Actions -> EC2 Power State -> Run workflow -> start
```
