# Newer versions of terraform require this

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure to run on AWS and specify the region

provider "aws" {
  region = "us-east-1"
}

# Deploy a custom VPC

resource "aws_vpc" "Project-VPC" {
  cidr_block = "10.16.0.0/16"
  
  tags = {
    Name = "Project-VPC"
  }
}

# Deploy an internet gateway

resource "aws_internet_gateway" "Project-IGW" {
  vpc_id = aws_vpc.Project-VPC.id

  tags = {
    Name = "Project-IGW"
  }
}

# Create a custom route table

resource "aws_route_table" "Project-RT" {
  vpc_id = aws_vpc.Project-VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Project-IGW.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.Project-IGW.id
  }

  tags = {
    Name = "Project-VPC"
  }
}

# Create a subnet for production

resource "aws_subnet" "Prod-SN" {
  vpc_id     = aws_vpc.Project-VPC.id
  cidr_block = "10.16.0.0/20"
  availability_zone = "us-east-1a"

  tags = {
    Name = "ProdSubnet"
    Environment = "Prod"
  }
}

# Associate subnet with RT

resource "aws_route_table_association" "Project-RTAssocation" {
  subnet_id      = aws_subnet.Prod-SN.id
  route_table_id = aws_route_table.Project-RT.id
}

# Create a security group to allow port 443, 80

resource "aws_security_group" "SG-Pub" {
  name        = "allow_web_traffic"
  description = "Allow inbound web traffic"
  vpc_id      = aws_vpc.Project-VPC.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
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

  tags = {
    Name = "SG-Pub"
    Environment = "Prod"
    Description = "Allow traffic"
  }
}

# Create a network interface

resource "aws_network_interface" "Project-NIC" {
  subnet_id       = aws_subnet.Prod-SN.id
  private_ips     = ["10.16.0.10"]
  security_groups = [aws_security_group.SG-Pub.id]

    tags = {
    Name = "Project-NIC"
  }
}

# Assign an elastic IP to the network interface we created

resource "aws_eip" "Project-EIP" {
  vpc                       = true
  network_interface         = aws_network_interface.Project-NIC.id
  associate_with_private_ip = "10.16.0.10"
  depends_on = [aws_internet_gateway.Project-IGW]

  tags = {
    Name = "Project-EIP"
  }
}

# Deploy a simple Production Ec2 Instance with Ubuntu

resource "aws_instance" "Pub-Server" {
  ami           = "ami-03d315ad33b9d49c4"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
   
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.Project-NIC.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt -y update
              sudo apt -y install apache2 -y
              sudo systemctl enable apache2
              sudo systemctl start apache2
              echo "<h1>This is the asdafsadfsdfsaf</h1>" > /var/www/html/index.html
    EOF
  tags = {
    Name = "Pub-Ubuntu-Server"
    Environment = "Prod"
  }
}

