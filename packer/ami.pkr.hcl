packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0, <2.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_source_ami" {
  type = string
}

variable "ami_name" {
  type    = string
  default = "trading-webapp-ami"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "docker_username" {
  type = string
}

variable "docker_token" {
  type      = string
  sensitive = true
}

source "amazon-ebs" "ubuntu" {
  ami_name        = "${var.ami_name}-${formatdate("YYYY_MM_DD_HHmmss", timestamp())}"
  instance_type   = var.instance_type
  region          = var.aws_region
  source_ami      = var.aws_source_ami
  ssh_username    = var.ssh_username
  ami_description = "AMI for setting up Trading Webapp"

  tags = {
    Name    = "Trading Webapp AMI"
    Builder = "Packer"
  }

  vpc_filter {
    filters = {
      "isDefault" : "true"
    }
  }

  ami_users = []
}

build {
  name = "go-webapp-ami"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "shell" {
    environment_vars = [
      "DB_USER=${var.db_user}",
      "DB_PASSWORD=${var.db_password}",
      "DOCKER_USERNAME=${var.docker_username}",
      "DOCKER_TOKEN=${var.docker_token}"
    ]
    script = "scripts/setup.sh"
  }

  provisioner "file" {
    content     = <<EOF
    DB_HOST=localhost
    DB_PORT=5432
    DB_USER=${var.db_user}
    DB_PASSWORD=${var.db_password}
    DB_NAME=trading_db
    EOF
    destination = "/tmp/app.env"
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /opt/trading-service",
      "sudo mv /tmp/app.env /opt/trading-service/.env",
      "sudo chmod 600 /opt/trading-service/.env"
    ]
  }
}
