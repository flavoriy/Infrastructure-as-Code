resource "aws_secretsmanager_secret" "this" {
  name                    = var.secret_name
  description             = var.description
  recovery_window_in_days = var.environment == "dev" ? 0 : 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = jsonencode(var.secret_values)
}
