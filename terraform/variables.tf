variable "aws_region" {
  description = "AWS region containing the Key Pair and default VPC."
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "Ubuntu 24.04 AMD64 AMI ID. Null selects the latest Canonical image in the region."
  type        = string
  default     = null

  validation {
    condition     = var.ami_id == null ? true : can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", var.ami_id))
    error_message = "Set ami_id to null or a valid EC2 AMI ID."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the x86-64 Ubuntu image."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 Key Pair."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Local path for an SSH client. Terraform does not read this file."
  type        = string
  default     = "~/.ssh/devops-key.pem"
}

variable "ssh_cidrs" {
  description = "IPv4 CIDRs that can connect to port 22."
  type        = set(string)

  validation {
    condition     = length(var.ssh_cidrs) > 0 && alltrue([for cidr in var.ssh_cidrs : can(cidrnetmask(cidr))])
    error_message = "Set at least one IPv4 CIDR for SSH."
  }
}

variable "app_cidrs" {
  description = "IPv4 CIDRs that can connect to port 3000."
  type        = set(string)

  validation {
    condition     = length(var.app_cidrs) > 0 && alltrue([for cidr in var.app_cidrs : can(cidrnetmask(cidr))])
    error_message = "Set at least one IPv4 CIDR for HTTP."
  }
}
