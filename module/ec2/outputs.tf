output "instance_id" {
  value = aws_instance.ec2.id
}

output "public_ip" {
  value = var.associate_eip ? aws_eip.eip[0].public_ip : aws_instance.ec2.public_ip
}

output "eip_allocation_id" {
  value = var.associate_eip ? aws_eip.eip[0].id : null
}

output "security_group_id" {
  value = aws_security_group.sg.id
}
