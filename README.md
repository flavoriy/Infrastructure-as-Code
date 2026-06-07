# Infrastructure as Code

Terraform code de tao ha tang AWS cho Jenkins va k3s lab. Terraform state duoc luu tren S3 backend.

## Ha Tang Hien Tai

Hien tai Terraform tao cac thanh phan chinh sau:

| Resource | Mo ta |
|----------|-------|
| VPC | `10.0.0.0/16` |
| Public subnet | `10.0.1.0/24` |
| Internet Gateway + Route Table | Cho phep truy cap internet |
| Jenkins server | EC2 `10.0.1.10`, ports `22`, `8080` |
| Jenkins agent | EC2 `10.0.1.11`, port `22` |
| k3s control-plane | EC2 `10.0.1.13`, ports `22`, `6443`, `30080`, `30443` |
| k3s worker 1 | EC2 `10.0.1.12`, ports `22`, `30080`, `30443` |
| k3s worker 2 | EC2 `10.0.1.14`, ports `22`, `30080`, `30443` |

Tat ca EC2 dung Elastic IP rieng, security group rieng, EBS gp3 encrypted va IMDSv2.

## Project Structure

```text
IaC/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── module/
│   ├── vpc/
│   └── ec2/
└── .github/workflows/
    ├── terraform.yml
    └── ec2-power-state.yml
```

## Terraform State

State duoc luu tren S3:

```hcl
bucket         = "bucket-project-devops-tfstate"
key            = "terraform.tfstate"
region         = "ap-southeast-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
```

State tren S3 giup Terraform biet resource nao da duoc tao, tu do update/destroy dung resource thay vi tao lung tung.

## Workflow 1: Terraform Infra

File: `.github/workflows/terraform.yml`

Workflow nay dung de tao, cap nhat hoac xoa ha tang bang Terraform.

### Khi nao chay?

| Trigger | Hanh dong |
|---------|-----------|
| Push vao `main` co thay doi `*.tf` hoac `*.tfvars` | Chay format, scan, plan |
| Pull request vao `main` | Chay format, scan, plan |
| Manual `apply` | Tao/cap nhat ha tang |
| Manual `destroy` | Xoa ha tang |

### Cac buoc chinh

```text
Checkout code
Configure AWS credentials
Setup Terraform
terraform init
terraform fmt -check
Checkov scan
terraform plan -out=tfplan
Block accidental EC2 replacement
terraform apply hoac terraform destroy
```

### Luu y

- `terraform init` la bat buoc tren GitHub Actions vi runner moi chua co backend/provider.
- Push/PR chi plan, khong apply.
- Chi manual `apply` moi tao hoac cap nhat ha tang.
- Chi manual `destroy` moi xoa ha tang.
- Step `Block accidental EC2 replacement` se chan neu plan muon xoa roi tao lai EC2, tru khi bat `allow_instance_replace=true`.

## Workflow 2: EC2 Power State

File: `.github/workflows/ec2-power-state.yml`

Workflow nay chi dung de bat hoac tat EC2 da ton tai. No khong dung Terraform.

### Input

| Input | Gia tri |
|-------|---------|
| `action` | `start` hoac `stop` |
| `project_name` | Mac dinh `jenkins-share-lib-project` |

### Instance duoc dieu khien

Workflow luon start/stop tat ca EC2 sau:

```text
jenkins-share-lib-project-jenkins_server
jenkins-share-lib-project-jenkins_agent
jenkins-share-lib-project-k3s
jenkins-share-lib-project-k3s_worker_1
jenkins-share-lib-project-k3s_worker_2
```

### Cach hoat dong

```text
Neu action = start:
  Tim cac instance dang stopped
  Goi aws ec2 start-instances

Neu action = stop:
  Tim cac instance dang running
  Goi aws ec2 stop-instances
```

Workflow nay khong chay `terraform init`, `terraform plan`, `terraform apply` hay `terraform destroy`, nen no khong tao lai instance va khong xoa ha tang.

## Cach Dung Nhanh

Tao hoac cap nhat ha tang:

```text
GitHub Actions -> Terraform Infra -> Run workflow -> action: apply
```

Xoa ha tang:

```text
GitHub Actions -> Terraform Infra -> Run workflow -> action: destroy
```

Tat toan bo EC2:

```text
GitHub Actions -> EC2 Power State -> Run workflow -> action: stop
```

Bat lai toan bo EC2:

```text
GitHub Actions -> EC2 Power State -> Run workflow -> action: start
```
