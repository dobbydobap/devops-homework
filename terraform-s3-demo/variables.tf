variable "aws_region" {
  type        = string
  description = "AWS region to create the bucket in."
  default     = "ap-south-1"
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket name. Must be globally unique across all AWS accounts."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket names must be 3-63 characters of lowercase letters, numbers, dots and hyphens."
  }
}

variable "owner" {
  type        = string
  description = "Name used in the Owner tag."
}

variable "environment" {
  type        = string
  description = "Environment tag."
  default     = "dev"
}
