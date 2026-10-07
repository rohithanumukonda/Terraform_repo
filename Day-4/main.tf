variable "aws_region" {
	description = "AWS region for the network and compute resources."
	type        = string
	default     = "us-east-1"
}

data "aws_availability_zones" "available" {
	state = "available"
}

data "aws_ami" "amazon_linux" {
	most_recent = true
	owners      = ["amazon"]

	filter {
		name   = "name"
		values = ["al2023-ami-2023.*-x86_64"]
	}

	filter {
		name   = "architecture"
		values = ["x86_64"]
	}

	filter {
		name   = "virtualization-type"
		values = ["hvm"]
	}
}

locals {
	availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "main" {
	cidr_block           = "10.0.0.0/16"
	enable_dns_support   = true
	enable_dns_hostnames = true

	tags = {
		Name = "day-4-vpc"
	}
}

resource "aws_subnet" "public_a" {
	vpc_id                  = aws_vpc.main.id
	cidr_block              = "10.0.1.0/24"
	availability_zone       = local.availability_zones[0]
	map_public_ip_on_launch = true

	tags = {
		Name = "day-4-public-a"
	}
}

resource "aws_subnet" "public_b" {
	vpc_id                  = aws_vpc.main.id
	cidr_block              = "10.0.2.0/24"
	availability_zone       = local.availability_zones[1]
	map_public_ip_on_launch = true

	tags = {
		Name = "day-4-public-b"
	}
}

resource "aws_subnet" "private" {
	vpc_id            = aws_vpc.main.id
	cidr_block        = "10.0.3.0/24"
	availability_zone = local.availability_zones[0]

	tags = {
		Name = "day-4-private"
	}
}

resource "aws_internet_gateway" "main" {
	vpc_id = aws_vpc.main.id

	tags = {
		Name = "day-4-igw"
	}
}

resource "aws_route_table" "public" {
	vpc_id = aws_vpc.main.id

	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_internet_gateway.main.id
	}

	tags = {
		Name = "day-4-public-routes"
	}
}

resource "aws_route_table_association" "public_a" {
	subnet_id      = aws_subnet.public_a.id
	route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
	subnet_id      = aws_subnet.public_b.id
	route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
	domain = "vpc"

	tags = {
		Name = "day-4-nat-eip"
	}
}

resource "aws_nat_gateway" "main" {
	allocation_id = aws_eip.nat.id
	subnet_id     = aws_subnet.public_a.id

	depends_on = [aws_internet_gateway.main]

	tags = {
		Name = "day-4-nat"
	}
}

resource "aws_route_table" "private" {
	vpc_id = aws_vpc.main.id

	route {
		cidr_block     = "0.0.0.0/0"
		nat_gateway_id = aws_nat_gateway.main.id
	}

	tags = {
		Name = "day-4-private-routes"
	}
}

resource "aws_route_table_association" "private" {
	subnet_id      = aws_subnet.private.id
	route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "load_balancer" {
	name        = "day-4-alb-sg"
	description = "Allow public HTTP traffic to the load balancer."
	vpc_id      = aws_vpc.main.id

	ingress {
		description = "HTTP from the internet"
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

resource "aws_security_group" "instances" {
	name        = "day-4-instance-sg"
	description = "Allow HTTP from the load balancer to the EC2 instances."
	vpc_id      = aws_vpc.main.id

	ingress {
		description     = "HTTP from the load balancer"
		from_port       = 80
		to_port         = 80
		protocol        = "tcp"
		security_groups = [aws_security_group.load_balancer.id]
	}

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
}

resource "aws_instance" "public" {
	ami                         = data.aws_ami.amazon_linux.id
	instance_type               = "t3.micro"
	subnet_id                   = aws_subnet.public_a.id
	associate_public_ip_address = true
	vpc_security_group_ids      = [aws_security_group.instances.id]
	user_data                   = <<-EOF
		#!/bin/bash
		dnf install -y nginx
		systemctl enable --now nginx
		echo "Hello from the public EC2 instance" > /usr/share/nginx/html/index.html
	EOF

	tags = {
		Name = "day-4-public-ec2"
	}
}

resource "aws_instance" "private" {
	ami                    = data.aws_ami.amazon_linux.id
	instance_type          = "t3.micro"
	subnet_id              = aws_subnet.private.id
	vpc_security_group_ids = [aws_security_group.instances.id]
	user_data              = <<-EOF
		#!/bin/bash
		dnf install -y nginx
		systemctl enable --now nginx
		echo "Hello from the private EC2 instance" > /usr/share/nginx/html/index.html
	EOF

	depends_on = [aws_route_table_association.private]

	tags = {
		Name = "day-4-private-ec2"
	}
}

resource "aws_lb" "main" {
	name               = "day-4-alb"
	internal           = false
	load_balancer_type = "application"
	security_groups    = [aws_security_group.load_balancer.id]
	subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

	tags = {
		Name = "day-4-alb"
	}
}

resource "aws_lb_target_group" "instances" {
	name     = "day-4-targets"
	port     = 80
	protocol = "HTTP"
	vpc_id   = aws_vpc.main.id

	health_check {
		path = "/"
	}
}

resource "aws_lb_target_group_attachment" "public" {
	target_group_arn = aws_lb_target_group.instances.arn
	target_id        = aws_instance.public.id
	port             = 80
}

resource "aws_lb_target_group_attachment" "private" {
	target_group_arn = aws_lb_target_group.instances.arn
	target_id        = aws_instance.private.id
	port             = 80
}

resource "aws_lb_listener" "http" {
	load_balancer_arn = aws_lb.main.arn
	port              = 80
	
    protocol          = "HTTP"

	default_action {
		type             = "forward"
		target_group_arn = aws_lb_target_group.instances.arn
	}
}

output "load_balancer_url" {
	description = "Public URL for the application load balancer."
	value       = "http://${aws_lb.main.dns_name}"
}

output "public_instance_id" {
	value = aws_instance.public.id
}

output "private_instance_id" {
	value = aws_instance.private.id
}
