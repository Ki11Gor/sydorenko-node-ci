terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "ubuntu" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "nodeapp" {
  name_prefix = "sydorenko-nodeapp-"
  description = "SSH and HTTP access for the Node.js lab"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "sydorenko-nodeapp"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = var.ssh_cidrs

  security_group_id = aws_security_group.nodeapp.id
  description       = "SSH for administration and deployment"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = var.app_cidrs

  security_group_id = aws_security_group.nodeapp.id
  description       = "HTTP for the Node.js app"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 3000
  to_port           = 3000
}

resource "aws_vpc_security_group_egress_rule" "internet" {
  security_group_id = aws_security_group.nodeapp.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "nodeapp" {
  ami                         = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.nodeapp.id]
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 12
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-BOOTSTRAP
    #!/bin/bash
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y ca-certificates curl openssl
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL --retry 3 https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    . /etc/os-release
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu %s stable\n' \
      "$(dpkg --print-architecture)" "$VERSION_CODENAME" > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    usermod -aG docker ubuntu

    install -d -m 0700 -o ubuntu -g ubuntu /home/ubuntu/nodeapp-docker
    env_file=/home/ubuntu/nodeapp-docker/.env
    if [[ ! -s "$env_file" ]]; then
      umask 077
      db_password=$(openssl rand -hex 24)
      printf 'POSTGRES_PASSWORD=%s\nAPP_BIND_ADDRESS=0.0.0.0\n' "$db_password" > "$env_file"
      chown ubuntu:ubuntu "$env_file"
    fi
  BOOTSTRAP

  depends_on = [aws_vpc_security_group_egress_rule.internet]

  tags = {
    Name = "sydorenko-nodeapp"
  }
}
