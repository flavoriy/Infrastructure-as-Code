resource "aws_secretsmanager_secret" "this" {
  #checkov:skip=CKV2_AWS_57:Automatic rotation is disabled to save costs and avoid key management complexity in this lab
  #checkov:skip=CKV_AWS_149:AWS-managed KMS encryption is sufficient, avoiding custom CMK cost in this lab

  name                    = var.secret_name
  description             = var.description
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-${var.environment}-secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = jsonencode(var.secret_values)
}
