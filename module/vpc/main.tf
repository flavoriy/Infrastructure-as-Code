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

resource "aws_subnet" "dev" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.dev_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false
  tags = {
    Name        = "${var.project_name}-dev-private-subnet"
    Environment = "dev"
  }
}

resource "aws_subnet" "prod" {
  count                   = length(var.prod_subnet_cidrs)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.prod_subnet_cidrs[count.index]
  availability_zone       = "${var.aws_region}${element(["a", "b", "c"], count.index)}"
  map_public_ip_on_launch = false
  tags = {
    Name                              = "${var.project_name}-prod-private-subnet-${count.index + 1}"
    Environment                       = "prod"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = "${var.aws_region}${element(["a", "b", "c"], count.index)}"
  map_public_ip_on_launch = true
  tags = {
    Name                     = "${var.project_name}-public-subnet-${count.index + 1}"
    Environment              = "public"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "${var.project_name}-nat-gw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "dev" {
  subnet_id      = aws_subnet.dev.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "prod" {
  count          = length(var.prod_subnet_cidrs)
  subnet_id      = aws_subnet.prod[count.index].id
  route_table_id = aws_route_table.private.id
}
