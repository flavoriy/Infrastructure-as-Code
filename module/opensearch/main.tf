# Security Group for OpenSearch Cluster
resource "aws_security_group" "opensearch" {
  name        = "${var.project_name}-${var.environment}-opensearch-sg"
  description = "Security group for OpenSearch cluster in VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow HTTPS within VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-opensearch-sg"
    Environment = var.environment
  }
}

# Create the service-linked role for OpenSearch
resource "aws_iam_service_linked_role" "opensearch" {
  aws_service_name = "opensearchservice.amazonaws.com"
}

# AWS OpenSearch Service Domain
resource "aws_opensearch_domain" "opensearch" {
  #checkov:skip=CKV_AWS_318:Three dedicated master nodes is omitted to save costs in this lab environment
  #checkov:skip=CKV_AWS_247:AWS-managed KMS encryption is sufficient, avoiding custom CMK cost in this lab
  #checkov:skip=CKV_AWS_84:Domain logging is disabled by default to save CloudWatch logging costs
  #checkov:skip=CKV_AWS_317:Domain audit logging is disabled to keep logging costs down
  #checkov:skip=CKV2_AWS_52:Fine-grained access control is not required for logs in this lab environment
  #checkov:skip=CKV2_AWS_59:Dedicated master node is disabled to save costs in this lab environment

  domain_name    = "${var.project_name}-${var.environment}-logs"
  engine_version = var.engine_version

  cluster_config {
    instance_type          = var.instance_type
    instance_count         = var.instance_count
    zone_awareness_enabled = var.instance_count > 1 ? true : false

    dynamic "zone_awareness_config" {
      for_each = var.instance_count > 1 ? [1] : []
      content {
        availability_zone_count = 2
      }
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = var.volume_type
    volume_size = var.volume_size
  }

  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.opensearch.id]
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-opensearch"
    Environment = var.environment
  }

  depends_on = [aws_iam_service_linked_role.opensearch]
}
