terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}



resource "aws_vpc" "starttech-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "starttech-vpc"
  }
}

resource "aws_internet_gateway" "starttech-igw" {
  vpc_id = aws_vpc.starttech-vpc.id

  tags = {
    Name = "starttech-igw"
  }
}

# ---------------- Public Subnets ----------------
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.starttech-vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                      = "starttech-public-${count.index + 1}"
    "kubernetes.io/role/elb"                  = "1"
    "kubernetes.io/cluster/starttech-cluster" = "shared"
  }
}

resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = {
    Name = "starttech-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "starttech-nat" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "starttech-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.starttech-igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.starttech-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.starttech-igw.id
  }

  tags = {
    Name = "starttech-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------- Private Subnets ----------------
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.starttech-vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                      = "starttech-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"         = "1"
    "kubernetes.io/cluster/starttech-cluster" = "shared"
  }
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.starttech-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.starttech-nat[count.index].id
  }

  tags = {
    Name = "starttech-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
