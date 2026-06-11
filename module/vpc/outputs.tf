output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "dev_subnet_id" {
  value = aws_subnet.dev.id
}

output "prod_subnet_id" {
  value = aws_subnet.prod.id
}

output "igw_id" {
  value = aws_internet_gateway.igw.id
}
