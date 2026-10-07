resource "aws_s3_bucket" "assets" {
  bucket_prefix = "${var.project}-assets-" # Terraform appends a random suffix, so the name is unique
  force_destroy = true

  tags = { Name = "${var.project}-assets" }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "readme" {
  bucket       = aws_s3_bucket.assets.id
  key          = "deployed-by-terraform.txt"
  content      = "Created by Terraform for session 19. EC2 instance: ${aws_instance.web.id}\n"
  content_type = "text/plain"
}
