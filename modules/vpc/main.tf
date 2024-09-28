provider "aws" {
  region = var.region
}

locals {
  default_prefix = "pos-tech-hiago"
}

resource "aws_vpc" "pos-tech-hiago-vpc" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Filtrar zonas de disponibilidade disponíveis
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Criar subnets públicas
resource "aws_subnet" "public_subnet" {
  count = 2 # Criar duas subnets públicas

  vpc_id                  = aws_vpc.pos-tech-hiago-vpc.id
  cidr_block              = cidrsubnet(aws_vpc.pos-tech-hiago-vpc.cidr_block, 8, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "my-public-subnet-${count.index + 1}"
  }
}

# Criar subnets privadas
resource "aws_subnet" "private_subnet" {
  count = 2 # Criar duas subnets privadas

  vpc_id            = aws_vpc.pos-tech-hiago-vpc.id
  cidr_block        = cidrsubnet(aws_vpc.pos-tech-hiago-vpc.cidr_block, 8, count.index + 2)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "my-private-subnet-${count.index + 1}"
  }
}

# Criar Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.pos-tech-hiago-vpc.id

  tags = {
    Name = "my-igw"
  }
}

# Criar Rota para a Internet nas subnets públicas
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.pos-tech-hiago-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "my-public-route-table"
  }
}

# Associar subnets públicas à tabela de roteamento
resource "aws_route_table_association" "public_subnet_association" {
  count          = length(aws_subnet.public_subnet)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

# Criar Nat Gateway para as subnets privadas
resource "aws_eip" "nat_eip" {
}
resource "aws_nat_gateway" "my_nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet[0].id # Usando a primeira subnet pública

  tags = {
    Name = "my-nat-gateway"
  }
}

# Criar tabela de roteamento para as subnets privadas
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.pos-tech-hiago-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_nat_gw.id
  }

  tags = {
    Name = "my-private-route-table"
  }
}

# Associar subnets privadas à tabela de roteamento
resource "aws_route_table_association" "private_subnet_association" {
  count          = length(aws_subnet.private_subnet)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}
