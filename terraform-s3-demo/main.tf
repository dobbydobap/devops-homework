resource "aws_s3_bucket" "demo" {
  bucket = var.bucket_name

  # lets `terraform destroy` remove the bucket even if objects were uploaded to it
  force_destroy = true

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

# keep every version of an object, so an overwrite or delete can be undone
resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id

  versioning_configuration {
    status = "Enabled"
  }
}

# encrypt objects at rest with S3-managed keys
resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# nothing in this bucket should ever be public
resource "aws_s3_bucket_public_access_block" "demo" {
  bucket = aws_s3_bucket.demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
