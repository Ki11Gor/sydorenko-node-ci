output "instance_ip" {
  description = "Public IPv4 address for the EC2_HOST GitHub secret."
  value       = aws_instance.nodeapp.public_ip
}

output "instance_id" {
  description = "EC2 instance ID for checking the console and system log."
  value       = aws_instance.nodeapp.id
}

output "app_url" {
  description = "Application URL for clients allowed by app_cidrs."
  value       = "http://${aws_instance.nodeapp.public_ip}:3000/"
}

output "ssh_private_key_path" {
  description = "Local key path used when connecting manually."
  value       = var.ssh_private_key_path
}
