variable "aws_region" {
  type        = string
  description = "AWS region for every resource."
  default     = "ap-south-1"
}

variable "project" {
  type        = string
  description = "Name prefix for resources."
  default     = "s19-cloud-infra"
}

variable "owner" {
  type        = string
  description = "Name used in the Owner tag."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet (must sit inside vpc_cidr)."
  default     = "10.20.1.0/24"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type. t3.micro is free-tier eligible."
  default     = "t3.micro"
}
