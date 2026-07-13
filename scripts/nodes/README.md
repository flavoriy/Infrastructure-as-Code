# Standalone per-node setup scripts

Each EC2 node directory contains a standalone `setup.bash` used for EC2 user_data bootstrap or manual configuration.

## Available node setups

1. `argo_server/setup.bash`: Installs single-node k3s and Argo CD management server.
2. `k3s_dev/setup.bash`: Installs single-node k3s for development environment.

> [!NOTE]
> Production environment uses **Amazon EKS Managed Node Group (`module.eks_prod`)**, which is fully managed by AWS & Terraform. Standalone node setup scripts are no longer required for Production.
