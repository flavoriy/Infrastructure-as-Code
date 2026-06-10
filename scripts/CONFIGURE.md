# EC2 configure runbook

Runbook nay dung de cau hinh nhanh cac EC2 sau khi `terraform apply`.

## Target topology

| EC2 | Terraform module | Private IP | Default type | Root disk | Public ports | Private ports | Role |
|---|---|---:|---|---:|---|---|---|
| Jenkins controller | `jenkins_server` | `10.0.1.10` | `t2.small` | 15 GB | `22`, `8080` | none | Jenkins UI/controller |
| Jenkins agent | `jenkins_agent` | `10.0.1.11` | `t2.micro` | 10 GB | `22` | none | Build Docker images and run CI tools |
| k3s dev | `k3s_dev` | `10.0.1.12` | `t2.small` | 15 GB | `22`, `6443`, `30080`, `30443` | none | Single-node dev cluster |
| k3s prod 1 | `k3s_prod_1` | `10.0.1.13` | `t2.small` | 15 GB | `22`, `6443`, `30080`, `30443` | TCP `2379`, `2380`, `10250`; UDP `8472` | First prod server node |
| k3s prod 2 | `k3s_prod_2` | `10.0.1.14` | `t2.small` | 15 GB | `22`, `6443`, `30080`, `30443` | TCP `2379`, `2380`, `10250`; UDP `8472` | Prod server node |

This profile uses about 5 project vCPUs. If another project already runs one `m7i-flex.large`, your account should have at least 8 Standard On-Demand vCPUs available.

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

If you want to save quota/cost temporarily:

```hcl
enable_jenkins_agent = false
enable_k3s_prod      = false
```

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

## 1. Jenkins controller

EC2: `jenkins_server`, private IP `10.0.1.10`.

Run:

```bash
cd /tmp/iac-scripts
bash common/00-base.sh
bash jenkins/10-controller.sh
```

If you do not use a separate Jenkins agent, also install Docker/tools on the controller:

```bash
bash common/10-docker.sh
bash jenkins/20-agent-tools.sh
```

Open Jenkins:

```text
http://<jenkins_server_public_ip>:8080
```

Get initial password:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Recommended plugins:

```text
Pipeline
Multibranch Pipeline
GitHub Branch Source
Git
Credentials
SSH Build Agents
SonarQube Scanner
JUnit
Warnings Next Generation
```

Jenkins credentials to create:

| ID | Type | Used for |
|---|---|---|
| `github-token` | username/password or secret text | Read app repo and shared library |
| `github-manifest-token` | username/password | Push or create PRs in GitOps manifest repo |
| `ghcr-token` | username/password or secret text | Push image to GHCR |
| `sonar-token` | secret text | SonarCloud scan |
| `argocd-token` | secret text | Optional ArgoCD verification |
| `tikto` | secret file | App build environment file if Docker build needs secrets |

SonarQube server config in Jenkins:

```text
Manage Jenkins -> System -> SonarQube servers
Name: SonarQube
Server URL: https://sonarcloud.io
Token: sonar-token
```

SonarCloud webhook:

```text
https://<jenkins_public_host>:8080/sonarqube-webhook/
```

## 2. Jenkins agent

EC2: `jenkins_agent`, private IP `10.0.1.11`.

Run:

```bash
cd /tmp/iac-scripts
bash common/00-base.sh
bash common/10-docker.sh
bash jenkins/20-agent-tools.sh
```

Create Jenkins node:

```text
Manage Jenkins -> Nodes -> New Node
Node name: agent
Type: Permanent Agent
Remote root directory: /home/ubuntu/jenkins-agent
Labels: agent
Launch method: Launch agents via SSH
Host: 10.0.1.11
Credentials: ubuntu SSH private key
Host Key Verification Strategy: Manually trusted or Non verifying for lab only
```

Verify on agent:

```bash
docker version
node --version
npm --version
trivy --version
sonar-scanner --version
```

If builds are slow or fail with out-of-memory, change `instance_type_jenkins_agent` to `t2.small` or `t3.small`.

## 3. k3s dev single node

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

## 4. k3s prod cluster

Prod is a 2-server k3s cluster with embedded etcd. This is a lab topology, not a quorum-safe HA topology.

Generate one shared token on your local machine or on `k3s_prod_1`:

```bash
openssl rand -hex 32
```

Use the same token on both prod nodes:

```bash
export K3S_TOKEN="replace-with-the-generated-token"
```

### k3s prod 1

EC2: `k3s_prod_1`, private IP `10.0.1.13`.

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

EC2: `k3s_prod_2`, private IP `10.0.1.14`.

Run:

```bash
cd /tmp/iac-scripts
bash common/00-base.sh
export K3S_TOKEN="same-token-as-prod-1"
bash k3s/41-prod-server-2.sh
```

Final prod verify on `k3s_prod_1`:

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

Jenkins:

```bash
systemctl status jenkins --no-pager
journalctl -u jenkins -n 100 --no-pager
```

Docker:

```bash
docker run --rm hello-world
```

k3s:

```bash
sudo systemctl status k3s --no-pager
sudo journalctl -u k3s -n 100 --no-pager
sudo k3s kubectl get nodes -o wide
```

Network:

```bash
curl -k https://10.0.1.13:6443/readyz
curl -k https://10.0.1.14:6443/readyz
```
