output "domain_endpoint" {
  description = "VPC Endpoint URL for OpenSearch domain"
  value       = aws_opensearch_domain.opensearch.endpoint
}

output "domain_arn" {
  description = "ARN of the OpenSearch domain"
  value       = aws_opensearch_domain.opensearch.arn
}

output "domain_id" {
  description = "Unique identifier for the OpenSearch domain"
  value       = aws_opensearch_domain.opensearch.domain_id
}

output "kibana_endpoint" {
  description = "OpenSearch Dashboards URL endpoint"
  value       = "${aws_opensearch_domain.opensearch.endpoint}/_dashboards"
}

output "security_group_id" {
  description = "Security Group ID of the OpenSearch cluster"
  value       = aws_security_group.opensearch.id
}
