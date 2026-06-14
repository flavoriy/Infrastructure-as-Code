# TikTo AWS Infrastructure

This repository defines the AWS infrastructure layer for TikTo using Terraform. It provisions the networking, security, public IP, and EC2 foundation used by self-managed k3s development and production-like environments.

Terraform is responsible for the cloud foundation only. k3s bootstrap, Argo CD, External Secrets Operator, and application workloads are installed or reconciled after the EC2 layer is available.

## Key Capabilities

- Reusable Terraform modules for AWS VPC, public subnets, route tables, security groups, Elastic IPs, and EC2 instances.
- A single-node k3s development environment and a three-server production-like k3s environment across three Availability Zones.
- Terraform remote state configured with Amazon S3 and DynamoDB locking.
- Checkov security scanning integrated into infrastructure review workflows.
- GitHub Actions automation for Terraform validation, planning, manual provisioning, cleanup, and EC2 start/stop cost control.
- A lifecycle guard that blocks accidental EC2 create, update, delete, or replace actions after initial provisioning.

## Architecture Summary

| Environment | Node | AZ | Private IP | Instance Type | Disk | Public Ingress | Private Ingress |
|---|---|---|---|---|---:|---|---|
| Dev | `k3s_dev` | `ap-southeast-1a` | `10.0.1.12` | `t2.small` | 15 GB | TCP `30080`, `30443`; restricted TCP `22`, `6443` | none |
| Prod | `k3s_prod_server_1` | `ap-southeast-1a` | `10.0.2.10` | `t3a.medium` | 20 GB | TCP `30080`, `30443`; restricted TCP `22`, `6443` | TCP `6443`, `2379`, `2380`, `10250`; UDP `8472` |
| Prod | `k3s_prod_server_2` | `ap-southeast-1b` | `10.0.3.10` | `t3a.medium` | 20 GB | TCP `30080`, `30443`; restricted TCP `22`, `6443` | TCP `6443`, `2379`, `2380`, `10250`; UDP `8472` |
| Prod | `k3s_prod_server_3` | `ap-southeast-1c` | `10.0.4.10` | `t3a.medium` | 20 GB | TCP `30080`, `30443`; restricted TCP `22`, `6443` | TCP `6443`, `2379`, `2380`, `10250`; UDP `8472` |

Total running footprint: 4 EC2 instances, 7 vCPUs, and 75 GB of root EBS storage.

## Network Design

| Resource | Value |
|---|---|
| AWS Region | `ap-southeast-1` |
| VPC CIDR | `10.0.0.0/16` |
| Dev subnet | `10.0.1.0/24` in `ap-southeast-1a` |
| Prod subnet 1 | `10.0.2.0/24` in `ap-southeast-1a` |
| Prod subnet 2 | `10.0.3.0/24` in `ap-southeast-1b` |
| Prod subnet 3 | `10.0.4.0/24` in `ap-southeast-1c` |
| Internet access | Internet Gateway and public route table |
| Public IP model | Explicit Elastic IP per EC2 instance |

The production cluster is designed as a three-server k3s topology with embedded etcd quorum. This is the minimum HA server topology for k3s and allows the control plane to tolerate one server failure.

## Repository Structure

```text
.
|-- main.tf
|-- variables.tf
|-- outputs.tf
|-- terraform.tfvars
|-- module/
|   |-- vpc/
|   `-- ec2/
|-- scripts/
|   |-- CONFIGURE.md
|   |-- common/
|   `-- k3s/
`-- .github/
    `-- workflows/
        |-- terraform.yml
        `-- ec2-power-state.yml
```

## Terraform Scope

Terraform provisions:

- VPC and public subnets.
- Internet Gateway and route table associations.
- Security groups for application NodePorts, restricted admin access, and private k3s server-to-server traffic.
- Elastic IPs and EC2 instances.
- Encrypted gp3 root volumes.
- EC2 metadata options.

Terraform does not install or manage:

- k3s.
- Argo CD.
- External Secrets Operator.
- Kubernetes application manifests.

Those responsibilities are handled later through setup scripts and the GitOps repository.

## Automation Workflows

| Workflow | Purpose |
|---|---|
| `.github/workflows/terraform.yml` | Runs Terraform formatting, validation, Checkov scanning, plan review, lifecycle guard checks, and manual apply/destroy operations |
| `.github/workflows/ec2-power-state.yml` | Starts or stops existing EC2 instances by Name tag for cost control without changing Terraform state |

## Terraform Backend

| Setting | Value |
|---|---|
| State bucket | `bucket-project-devops-tfstate` |
| State key | `terraform.tfstate` |
| Lock table | `terraform-state-lock` |
| Region | `ap-southeast-1` |
| Encryption | Enabled |

Before applying, verify that the selected backend owns the expected resources:

```bash
terraform init
terraform state list
```

If `terraform state list` is empty while EC2 instances already exist in AWS, stop. The backend or state key is not pointing at the state that owns those resources, or the resources need to be imported. Applying in that condition can create duplicate infrastructure.

## Security and Operations

- Root EBS volumes are encrypted.
- EC2 detailed monitoring is disabled by default to keep the environment cost-aware.
- CPU credits are configured as standard to avoid unlimited burst charges.
- Admin ports such as SSH and Kubernetes API are separated from application NodePorts.
- Production server-to-server ports are limited to production subnet CIDRs.
- Checkov is used to catch common Terraform security issues in CI.
- External Secrets requires the EC2 nodes running the controller to have an IAM instance profile with Secrets Manager read access.
- External Secrets also requires EC2 metadata to be reachable from pods; in this k3s-on-EC2 setup that means `HttpEndpoint=enabled` and `HttpPutResponseHopLimit=2` on the relevant nodes.

The IAM instance profile and metadata hop limit are required for the GitOps runtime. If they are changed manually in AWS, they should be codified in Terraform so the environment remains reproducible.

## Outputs

```bash
terraform output
```

| Output | Meaning |
|---|---|
| `k3s_dev_public_ip` | Public IP for the dev k3s node |
| `k3s_prod_public_ips` | Public IP list for the three production k3s servers |
| `k3s_prod_server_1_public_ip` | Public IP for production server 1 |
| `k3s_prod_server_2_public_ip` | Public IP for production server 2 |
| `k3s_prod_server_3_public_ip` | Public IP for production server 3 |
| `k3s_dev_private_ip` | Private IP for the dev node |
| `k3s_prod_private_ips` | Private IP list for production servers |

## Notes

- Terraform version: `>= 1.1`
- AWS region: `ap-southeast-1`
- Default project name: `devops-project`
- Default SSH key pair: `devops-project`
- AMI is configured through `terraform.tfvars`
