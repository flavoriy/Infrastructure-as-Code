resource "aws_security_group" "sg" {
  name        = "${var.project_name}-${var.instance_name}-sg"
  description = "Security group for ${var.instance_name}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      description = "Allow port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.instance_name}-sg"
  }
}


resource "aws_eip" "eip" {
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-${var.instance_name}-eip"
  }
}


resource "aws_instance" "ec2" {
  ami                         = var.aws_ami_id
  instance_type               = var.aws_instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.sg.id]
  subnet_id                   = var.subnet_id
  private_ip                  = var.private_ip
  associate_public_ip_address = false
  ebs_optimized               = true
  monitoring                  = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-${var.instance_name}"
  }
}


resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.ec2.id
  allocation_id = aws_eip.eip.id
}


resource "aws_ec2_instance_state" "state" {
  instance_id = aws_instance.ec2.id
  state       = var.instance_state

  depends_on = [aws_eip_association.eip_assoc]
}
