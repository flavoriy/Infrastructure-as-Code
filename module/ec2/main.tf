#checkov:skip=CKV_AWS_382:Outbound internet access required for package downloads in DevOps environment
resource "aws_security_group" "sg" {
  name        = "${var.project_name}-${var.instance_name}-sg"
  description = "Security group for ${var.instance_name}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description = lookup(ingress.value, "description", null)
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
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
  count  = var.associate_eip ? 1 : 0
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-${var.instance_name}-eip"
  }
}


module "ssm_iam" {
  source                  = "../iam"
  project_name            = var.project_name
  role_name               = "${var.project_name}-${var.instance_name}-ssm-role"
  assume_role_service     = "ec2.amazonaws.com"
  managed_policy_arns     = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  create_instance_profile = true
}


resource "aws_instance" "ec2" {
  #checkov:skip=CKV_AWS_88:Public IP is required for public access to management and dev services in this lab
  #checkov:skip=CKV_AWS_126:Detailed monitoring is disabled to keep costs within lab limits

  ami                         = var.aws_ami_id
  instance_type               = var.aws_instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.sg.id]
  subnet_id                   = var.subnet_id
  private_ip                  = var.private_ip
  associate_public_ip_address = var.associate_eip ? false : true
  iam_instance_profile        = module.ssm_iam.instance_profile_name
  monitoring                  = var.enable_detailed_monitoring
  ebs_optimized               = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = var.user_data

  dynamic "credit_specification" {
    for_each = length(regexall("^t[0-9]", var.aws_instance_type)) > 0 ? [var.cpu_credits] : []
    content {
      cpu_credits = credit_specification.value
    }
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
  count         = var.associate_eip ? 1 : 0
  instance_id   = aws_instance.ec2.id
  allocation_id = aws_eip.eip[0].id
}
