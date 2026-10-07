# =========================================
# VPC
# =========================================

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "ASRR_VPC"
  }
}


# =========================================
# INTERNET GATEWAY
# =========================================

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "ASRR_IGW"
  }
}


# =========================================
# PUBLIC SUBNET
# =========================================

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "ASRR_Public_Subnet"
  }
}


# =========================================
# PRIVATE SUBNET
# =========================================

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "ASRR_Private_Subnet"
  }
}


# =========================================
# ELASTIC IP FOR NAT GATEWAY
# =========================================

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "ASRR_NAT_EIP"
  }
}


# =========================================
# NAT GATEWAY
# =========================================

resource "aws_nat_gateway" "my_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "ASRR_NAT_Gateway"
  }

  depends_on = [
    aws_internet_gateway.my_igw
  ]
}


# =========================================
# PUBLIC ROUTE TABLE
# =========================================

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "ASRR_Public_RT"
  }
}


# =========================================
# PUBLIC ROUTE
# Internet Gateway → Internet
# =========================================

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw.id
}


# =========================================
# PUBLIC ROUTE TABLE ASSOCIATION
# =========================================

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


# =========================================
# PRIVATE ROUTE TABLE
# =========================================

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "ASRR_Private_RT"
  }
}


# =========================================
# PRIVATE ROUTE
# Private Subnet → NAT Gateway → Internet
# =========================================

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my_nat.id
}


# =========================================
# PRIVATE ROUTE TABLE ASSOCIATION
# =========================================

resource "aws_route_table_association" "private_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}


# =========================================
# SECURITY GROUP
# ALL INBOUND + ALL OUTBOUND
# =========================================

resource "aws_security_group" "allow_all" {
  name        = "ASRR-Allow-All"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description      = "Allow all inbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ASRR-Allow-All-SG"
  }
}