#checkov:skip=CKV2_AWS_11:VPC Flow Logs not required for this DevOps lab environment
resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.project_name}-default-sg-restricted"
  }
}

moved {
  from = aws_subnet.subnet
  to   = aws_subnet.dev
}

moved {
  from = aws_route_table_association.rta
  to   = aws_route_table_association.dev
}

resource "aws_subnet" "dev" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.dev_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false
  tags = {
    Name        = "${var.project_name}-dev-public-subnet"
    Environment = "dev"
  }
}

resource "aws_subnet" "prod" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.prod_subnet_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false
  tags = {
    Name        = "${var.project_name}-prod-public-subnet"
    Environment = "prod"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.project_name}-rt"
  }
}

resource "aws_route_table_association" "dev" {
  subnet_id      = aws_subnet.dev.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "prod" {
  subnet_id      = aws_subnet.prod.id
  route_table_id = aws_route_table.rt.id
}
