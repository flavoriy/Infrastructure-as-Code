locals {
  # Default fallback secrets if variables are missing or incomplete
  default_dev_secrets = {
    DATABASE_URL                         = "postgresql://user:password@host:5432/tikto_dev"
    TIKTO_INTERNAL_API_KEY               = "dev-internal-api-key-secret"
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "dev-supabase-key"
  }

  default_prod_secrets = {
    DATABASE_URL                         = "postgresql://user:password@host:5432/tikto_prod"
    TIKTO_INTERNAL_API_KEY               = "prod-internal-api-key-secret"
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "prod-supabase-key"
  }

  # Build overrides from variables (non-null values only)
  var_secrets = {
    for k, v in {
      DATABASE_URL                         = var.database_url
      CALENDAR_DATABASE_URL                = var.calendar_database_url
      PROFILE_DATABASE_URL                 = var.profile_database_url
      TASKS_DATABASE_URL                   = var.tasks_database_url
      TIKTO_CALENDAR_API_URL               = var.tikto_calendar_api_url
      TIKTO_DASHBOARD_API_URL              = var.tikto_dashboard_api_url
      TIKTO_PROFILE_API_URL                = var.tikto_profile_api_url
      TIKTO_TASKS_API_URL                  = var.tikto_tasks_api_url
      NEXT_PUBLIC_APP_URL                  = var.next_public_app_url
      TIKTO_INTERNAL_API_KEY               = var.tikto_internal_api_key
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = var.next_public_supabase_publishable_key
      SONAR_TOKEN                          = var.sonar_token
      GITOPS_TOKEN                         = var.gitops_token
      GITOPS_USERNAME                      = var.gitops_username
      TOKEN_ENCRYPTION_KEY                 = var.token_encryption_key
    } : k => v if v != null
  }

  final_dev_secrets  = merge(local.default_dev_secrets, local.var_secrets)
  final_prod_secrets = merge(local.default_prod_secrets, local.var_secrets)
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
