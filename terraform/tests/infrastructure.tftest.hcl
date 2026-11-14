mock_provider "aws" {
  mock_data "aws_vpc" {
    defaults = {
      id = "vpc-0123456789abcdef0"
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }

  mock_resource "aws_instance" {
    defaults = {
      id        = "i-0123456789abcdef0"
      public_ip = "192.0.2.20"
    }
  }
}

variables {
  ami_id        = null
  instance_type = "t3.micro"
  key_name      = "test-key"
  ssh_cidrs     = ["192.0.2.10/32"]
  app_cidrs     = ["192.0.2.10/32"]
}

run "plan_ec2" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.ssh["192.0.2.10/32"].from_port == 22 && aws_vpc_security_group_ingress_rule.ssh["192.0.2.10/32"].to_port == 22
    error_message = "SSH must use TCP port 22."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.http["192.0.2.10/32"].from_port == 3000 && aws_vpc_security_group_ingress_rule.http["192.0.2.10/32"].to_port == 3000
    error_message = "The application must use TCP port 3000."
  }

  assert {
    condition     = aws_instance.nodeapp.key_name == "test-key" && aws_instance.nodeapp.associate_public_ip_address
    error_message = "EC2 must use the specified key pair and request a public IPv4 address."
  }
}

run "apply_with_mock_aws" {
  command = apply

  assert {
    condition     = output.instance_ip == "192.0.2.20" && output.app_url == "http://192.0.2.20:3000/"
    error_message = "Terraform must expose the EC2 public IP and HTTP URL."
  }
}
