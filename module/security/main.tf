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
          var.secret_arn,
          "${var.secret_arn}-*"
        ]
      }
    ]
  })
}

# Attach Secrets Manager Policy to EKS Node Role
resource "aws_iam_role_policy_attachment" "eks_node_secrets_manager" {
  policy_arn = aws_iam_policy.secrets_manager_read.arn
  role       = var.eks_node_role_name
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
          "${var.opensearch_domain_arn}/*",
          var.opensearch_domain_arn
        ]
      }
    ]
  })
}

# Attach OpenSearch Policy to EKS Node Role
resource "aws_iam_role_policy_attachment" "eks_node_opensearch" {
  policy_arn = aws_iam_policy.opensearch_ingest.arn
  role       = var.eks_node_role_name
}
