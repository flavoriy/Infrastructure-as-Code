# Read local .env file if present in IaC directory
locals {
  env_file_path   = "${path.module}/.env"
  env_file_exists = fileexists(local.env_file_path)

  # Read file lines and filter non-empty, non-comment lines containing '='
  raw_env_lines = local.env_file_exists ? compact(split("\n", file(local.env_file_path))) : []
  valid_env_lines = [
    for line in local.raw_env_lines :
    trimspace(line)
    if length(trimspace(line)) > 0 && !startswith(trimspace(line), "#") && contains(split("", line), "=")
  ]

  # Parse KEY=VALUE lines into a map
  parsed_env_vars = {
    for line in local.valid_env_lines :
    trimspace(split("=", line)[0]) => trimspace(join("=", slice(split("=", line), 1, length(split("=", line)))))
  }

  # Default fallback secrets if .env is missing or incomplete
  default_dev_secrets = {
    DATABASE_URL                         = "postgresql://user:password@host:5432/tikto_dev"
    TIKTO_INTERNAL_API_KEY              = "dev-internal-api-key-secret"
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "dev-supabase-key"
  }

  default_prod_secrets = {
    DATABASE_URL                         = "postgresql://user:password@host:5432/tikto_prod"
    TIKTO_INTERNAL_API_KEY              = "prod-internal-api-key-secret"
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "prod-supabase-key"
  }

  final_dev_secrets  = merge(local.default_dev_secrets, local.parsed_env_vars)
  final_prod_secrets = merge(local.default_prod_secrets, local.parsed_env_vars)
}

# Reusable Secrets Manager Module for Development Environment
module "secrets_dev" {
  source        = "./module/secrets_manager"
  project_name  = var.project_name
  environment   = "dev"
  secret_name   = var.secret_key_dev
  description   = "Application runtime secrets for TikTo Development environment"
  secret_values = local.final_dev_secrets
}

# Reusable Secrets Manager Module for Production Environment
module "secrets_prod" {
  source        = "./module/secrets_manager"
  project_name  = var.project_name
  environment   = "prod"
  secret_name   = var.secret_key_prod
  description   = "Application runtime secrets for TikTo Production environment"
  secret_values = local.final_prod_secrets
}

# IAM Policy: Allow reading Secrets Manager secrets
resource "aws_iam_policy" "secrets_manager_read" {
  name        = "${var.project_name}-secrets-manager-read-policy"
  description = "Allows EKS worker nodes and External Secrets Operator to read TikTo secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          module.secrets_dev.secret_arn,
          module.secrets_prod.secret_arn,
          "${module.secrets_dev.secret_arn}-*",
          "${module.secrets_prod.secret_arn}-*"
        ]
      }
    ]
  })
}

# Attach Secrets Manager Policy to EKS Node Role
resource "aws_iam_role_policy_attachment" "eks_node_secrets_manager" {
  policy_arn = aws_iam_policy.secrets_manager_read.arn
  role       = module.eks_prod.node_role_name
}

# IAM Policy: Allow OpenSearch log ingestion from EKS nodes
resource "aws_iam_policy" "opensearch_ingest" {
  name        = "${var.project_name}-opensearch-ingest-policy"
  description = "Allows EKS worker nodes (Fluent Bit) to send logs to AWS OpenSearch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpGet",
          "es:ESHttpHead"
        ]
        Resource = [
          "${module.opensearch_prod.domain_arn}/*",
          module.opensearch_prod.domain_arn
        ]
      }
    ]
  })
}

# Attach OpenSearch Policy to EKS Node Role
resource "aws_iam_role_policy_attachment" "eks_node_opensearch" {
  policy_arn = aws_iam_policy.opensearch_ingest.arn
  role       = module.eks_prod.node_role_name
}
