terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.region]
    }
  }
}

resource "aws_vpc" "main" {
  provider             = aws.region
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "hive-gateway-vpc-${var.region}"
  }
}

resource "aws_subnet" "main" {
  provider          = aws.region
  count             = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "hive-gateway-subnet-${var.region}-${var.availability_zones[count.index]}"
  }
}

resource "aws_internet_gateway" "main" {
  provider = aws.region
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "hive-gateway-igw-${var.region}"
  }
}

resource "aws_route_table" "main" {
  provider = aws.region
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "hive-gateway-rt-${var.region}"
  }
}

resource "aws_route_table_association" "main" {
  provider       = aws.region
  count          = length(aws_subnet.main)
  subnet_id      = aws_subnet.main[count.index].id
  route_table_id = aws_route_table.main.id
}