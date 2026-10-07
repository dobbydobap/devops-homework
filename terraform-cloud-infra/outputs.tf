output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Public subnet ID."
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Web security group ID."
  value       = aws_security_group.web.id
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.web.id
}

output "ami_used" {
  description = "AMI the instance booted from."
  value       = data.aws_ami.al2023.name
}

output "public_ip" {
  description = "EC2 public IP."
  value       = aws_instance.web.public_ip
}

output "website_url" {
  description = "Open this once nginx has installed (about a minute after apply)."
  value       = "http://${aws_instance.web.public_ip}"
}

output "s3_bucket" {
  description = "S3 bucket name."
  value       = aws_s3_bucket.assets.bucket
}
