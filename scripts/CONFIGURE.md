# EC2 configure runbook

Runbook này dùng để cấu hình nhanh các EC2 sau khi `terraform apply`.

Terraform chỉ tạo hạ tầng AWS. Các script trong thư mục này cài đặt phần mềm bên trong EC2: base OS packages, k3s, và Argo CD.

Dùng workflow như sau:

1. `Terraform Infra` manual `apply`: tạo VPC, dev/prod subnets, security groups, EIP, EC2.
2. Chạy các script cấu hình trong runbook này trên từng EC2 phù hợp.
3. `EC2 Power State` manual `stop`/`start`: bật tắt EC2 đã tồn tại, không tạo lại instance.
4. `Terraform Infra` manual `destroy`: hủy toàn bộ hạ tầng khi không cần lab nữa.

## Target topology

| EC2 | Terraform module | Private IP | Default type | Root disk | Public ports | Private ports | Role |
|---|---|---:|---|---:|---|---|---|
| k3s dev | `k3s_dev` | `10.0.1.12` | `t2.small` | 15 GB | `30080`, `30443`; `22`, `6443` (restricted) | none | Single-node dev cluster |
| k3s prod server 1 | `k3s_prod_server_1` | `10.0.2.10` | `t3a.medium` | 20 GB | `30080`, `30443`; `22`, `6443` (restricted) | From prod subnets: TCP `6443`, `2379`, `2380`, `10250`; UDP `8472` | First prod server node |
| k3s prod server 2 | `k3s_prod_server_2` | `10.0.3.10` | `t3a.medium` | 20 GB | `30080`, `30443`; `22`, `6443` (restricted) | From prod subnets: TCP `6443`, `2379`, `2380`, `10250`; UDP `8472` | Second prod server node |
| k3s prod server 3 | `k3s_prod_server_3` | `10.0.4.10` | `t3a.medium` | 20 GB | `30080`, `30443`; `22`, `6443` (restricted) | From prod subnets: TCP `6443`, `2379`, `2380`, `10250`; UDP `8472` | Third prod server node |

This profile uses 7 project vCPUs when every EC2 instance is running.

The prod cluster uses three k3s server nodes with embedded etcd quorum. It can tolerate one k3s server failure at the cluster level, and the prod subnets are spread across three Availability Zones (ap-southeast-1a, 1b, 1c), providing full multi-AZ HA at the infrastructure level.

## Script inventory

| Script | Run on | Purpose |
|---|---|---|
| `common/00-base.sh` | all EC2 nodes | Installs common OS tools, disables swap, and enables kernel settings needed by k3s |
| `k3s/30-dev-single-node.sh` | k3s dev | Installs one standalone k3s server |
| `k3s/40-prod-server-1.sh` | k3s prod server 1 | Initializes the prod k3s embedded-etcd cluster |
| `k3s/41-prod-server-2.sh` | k3s prod server 2 | Joins the second server to the prod k3s cluster |
| `k3s/42-prod-server-3.sh` | k3s prod server 3 | Joins the third server to the prod k3s cluster |
| `k3s/50-install-argocd.sh` | a configured k3s node | Installs Argo CD into the current cluster |

## Per-node setup wrappers

For a simpler run, use one wrapper folder per EC2 under `nodes/`. Each `setup.bash` runs the required base script and the node-specific install scripts in order.

| EC2 | Wrapper | Notes |
|---|---|---|
| `k3s_dev` | `bash nodes/k3s_dev/setup.bash` | Standalone dev cluster |
| `k3s_prod_server_1` | `export K3S_TOKEN="same-token"; bash nodes/k3s_prod_server_1/setup.bash` | Run first; initializes prod embedded-etcd |
| `k3s_prod_server_2` | `export K3S_TOKEN="same-token"; bash nodes/k3s_prod_server_2/setup.bash` | Run after prod server 1 is ready |
| `k3s_prod_server_3` | `export K3S_TOKEN="same-token"; bash nodes/k3s_prod_server_3/setup.bash` | Run after prod server 1 is ready |

Generate the prod token once and reuse it on all three prod servers:

```bash
openssl rand -hex 32
```

Argo CD is intentionally left out of the wrappers. Install it only after the target k3s cluster is ready:

- Dev: run `bash k3s/50-install-argocd.sh` on `k3s_dev` after `nodes/k3s_dev/setup.bash`.
- Prod: run `bash k3s/50-install-argocd.sh` on `k3s_prod_server_1` after all three prod servers are `Ready`.

## Deploy infra

From local machine:

```bash
cd IaC
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
terraform output
```

To save cost temporarily after provisioning, use the `EC2 Power State` workflow with action `stop`. That workflow only stops instances and does not modify Terraform state.

## Copy scripts to EC2

Replace `PUBLIC_IP` with the output of Terraform.

```bash
scp -r -i /path/to/jenkins-share-lib.pem scripts ubuntu@PUBLIC_IP:/tmp/iac-scripts
```

Run scripts through SSH:

```bash
ssh -i /path/to/jenkins-share-lib.pem ubuntu@PUBLIC_IP
cd /tmp/iac-scripts
```

## 1. k3s dev single node

EC2: `k3s_dev`, private IP `10.0.1.12`.

Run:

```bash
cd /tmp/iac-scripts
bash common/00-base.sh
bash k3s/30-dev-single-node.sh
```

Verify:

```bash
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -A
```

Install ArgoCD in dev cluster:

```bash
bash k3s/50-install-argocd.sh
```

Apply only the dev ArgoCD application in the dev cluster:

```bash
kubectl apply -f https://raw.githubusercontent.com/Flavoriy/gitops-manifest/main/argocd/projects/tikto.yaml
kubectl apply -f https://raw.githubusercontent.com/Flavoriy/gitops-manifest/main/argocd/applications/tikto-dev.yaml
```

Before using the commands above, replace the repo URL in `gitops-manifest/argocd` with the real repo URL.

## 2. k3s prod cluster

Prod is a 3-server k3s cluster with embedded etcd quorum. This is the minimum k3s HA server topology and can tolerate one server failure.

Generate one shared token on your local machine or on `k3s_prod_server_1`:

```bash
openssl rand -hex 32
```

Use the same token on all three prod nodes:

```bash
export K3S_TOKEN="replace-with-the-generated-token"
```

### k3s prod 1

EC2: `k3s_prod_server_1`, private IP `10.0.2.10`.

Run:

```bash
cd /tmp/iac-scripts
bash common/00-base.sh
export K3S_TOKEN="replace-with-the-generated-token"
bash k3s/40-prod-server-1.sh
```

Verify:

```bash
sudo k3s kubectl get nodes -o wide
```

### k3s prod 2

EC2: `k3s_prod_server_2`, private IP `10.0.3.10`.

Run:

```bash
cd /tmp/iac-scripts
bash common/00-base.sh
export K3S_TOKEN="same-token-as-prod-1"
bash k3s/41-prod-server-2.sh
```

### k3s prod 3

EC2: `k3s_prod_server_3`, private IP `10.0.4.10`.

Run:

```bash
cd /tmp/iac-scripts
bash common/00-base.sh
export K3S_TOKEN="same-token-as-prod-1"
bash k3s/42-prod-server-3.sh
```

Final prod verify on `k3s_prod_server_1`:

```bash
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -A
```

Install ArgoCD in prod cluster:

```bash
bash k3s/50-install-argocd.sh
```

Apply only the prod ArgoCD application in the prod cluster:

```bash
kubectl apply -f https://raw.githubusercontent.com/Flavoriy/gitops-manifest/main/argocd/projects/tikto.yaml
kubectl apply -f https://raw.githubusercontent.com/Flavoriy/gitops-manifest/main/argocd/applications/tikto-prod.yaml
```

## Kubeconfig for local kubectl

On a k3s node:

```bash
sudo cat /etc/rancher/k3s/k3s.yaml
```

Copy it to your local machine and replace:

```text
https://127.0.0.1:6443
```

with:

```text
https://<k3s_public_ip>:6443
```

The install scripts add private and public IPs to TLS SANs so this works from local.

## Quick health checks

k3s:

```bash
sudo systemctl status k3s --no-pager
sudo journalctl -u k3s -n 100 --no-pager
sudo k3s kubectl get nodes -o wide
```

Network:

```bash
curl -k https://10.0.2.10:6443/readyz
curl -k https://10.0.3.10:6443/readyz
curl -k https://10.0.4.10:6443/readyz
```
