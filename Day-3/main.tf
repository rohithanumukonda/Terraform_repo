#creation of VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ASRR_VPC"
  }
}

#creation of public subnet
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "ASRR_Main_Subnet"
  }
}

#creation of private subnet
resource "aws_subnet" "main2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "ASRR_Main_Subnet_2"
  }
}

#creation of internet gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "ASRR_IGW"
  }
}

#creation of route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "ASRR_Public_RT"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

#creation of route table association
resource "aws_route_table_association" "public_rt_assoc_main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.public_rt.id
}

#creation of security group 
resource "aws_security_group" "my_sg" {
  name        = "ASRR_SG"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#creation of ec2 instance in public subnet
resource "aws_instance" "my_instance" {
  ami             = "ami-0b245cc5f82576748"
instance_type = "t3.micro"
  subnet_id       = aws_subnet.main.id
vpc_security_group_ids = [aws_security_group.my_sg.id]
  tags = {
    Name = "ASRR_Instance"
  }
}