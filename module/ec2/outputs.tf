output "instance_id" {
  value = aws_instance.ec2.id
}

output "public_ip" {
  value = aws_eip.eip.public_ip
}

output "eip_allocation_id" {
  value = aws_eip.eip.id
}

output "security_group_id" {
  value = aws_security_group.sg.id
}
