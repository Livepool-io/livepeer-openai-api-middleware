# This networking.tf file does the following:

# Creates a VPC in each region.
# Creates two subnets in each VPC, spread across two availability zones.
# Creates an Internet Gateway for each VPC to allow internet access.
# Creates a route table for each VPC and adds a route to the Internet Gateway.
# Associates the route table with each subnet.

#The for_each meta-argument is used extensively here to create resources for each region. The provider argument is used to specify which regional provider should be used for each resource.
# This sets up the basic network infrastructure in each region.

# Create a VPC in each region
resource "aws_vpc" "main" {
  for_each = toset(var.regions)

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "hive-gateway-vpc-${each.key}"
  }

  provider = aws[each.key]
}

# Create two subnets in each VPC
resource "aws_subnet" "main" {
  for_each = { for pair in setproduct(var.regions, ["a", "b"]) : "${pair[0]}-${pair[1]}" => pair }

  vpc_id            = aws_vpc.main[each.value[0]].id
  cidr_block        = cidrsubnet(aws_vpc.main[each.value[0]].cidr_block, 8, index(var.regions, each.value[0]) * 2 + (each.value[1] == "a" ? 0 : 1))
  availability_zone = "${each.value[0]}${each.value[1]}"

  tags = {
    Name = "hive-gateway-subnet-${each.key}"
  }

  provider = aws[each.value[0]]
}

# Create an Internet Gateway for each VPC
resource "aws_internet_gateway" "main" {
  for_each = toset(var.regions)

  vpc_id = aws_vpc.main[each.key].id

  tags = {
    Name = "hive-gateway-igw-${each.key}"
  }

  provider = aws[each.key]
}

# Create a route table for each VPC
resource "aws_route_table" "main" {
  for_each = toset(var.regions)

  vpc_id = aws_vpc.main[each.key].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[each.key].id
  }

  tags = {
    Name = "hive-gateway-rt-${each.key}"
  }

  provider = aws[each.key]
}

# Associate the route table with each subnet
resource "aws_route_table_association" "main" {
  for_each = aws_subnet.main

  subnet_id      = each.value.id
  route_table_id = aws_route_table.main[split("-", each.key)[0]].id

  provider = aws[split("-", each.key)[0]]
}