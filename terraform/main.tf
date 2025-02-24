provider "aws" {
  region = var.aws_region
}

# Data source to fetch the latest Trading Webapp AMI
data "aws_ami" "trading_webapp" {
  most_recent = true
  owners  = ["self"]
  filter {
    name   = "name"
    values = ["trading-webapp-ami-*"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-route-table"
  }
}

# Route Table for Private Subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-route-table"
  }
}

# Route Table Association for Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table Association for Private Subnets
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Group for Web Application
resource "aws_security_group" "webapp_sg" {
  name        = "${var.project_name}-webapp-sg"
  description = "Security group for trading webapp"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP access on port 8080
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description = "Allow HTTP access to the trading webapp"
  }

  # Allow SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
    description = "Allow SSH access from restricted IPs"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-webapp-sg"
  }
}

# EC2 Instance for Trading Webapp
resource "aws_instance" "webapp" {
  ami           = data.aws_ami.trading_webapp.id
  instance_type = var.instance_type
  #   key_name               = var.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.webapp_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Starting trading webapp service..."
              systemctl start trading-webapp
              systemctl enable trading-webapp
              EOF

  tags = {
    Name = "Trading Webapp VM"
  }
}

# Output the public IP address of the EC2 instance
output "webapp_url" {
  value       = "http://${aws_instance.webapp.public_ip}:8080/orders"
  description = "URL to access the trading webapp orders endpoint"
}

output "instance_ip" {
  value       = aws_instance.webapp.public_ip
  description = "Public IP address of the trading webapp instance"
}