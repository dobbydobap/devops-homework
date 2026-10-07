# Points the AWS provider at a local Moto server (an open-source AWS emulator in Docker)
# instead of real AWS, because this project was run without an AWS account.
#   docker run -d --name moto -p 5000:5000 motoserver/moto:latest
# Terraform merges *_override.tf files into the configuration automatically.
# Delete this file to run the same code against real AWS.
provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    s3  = "http://localhost:5000"
    ec2 = "http://localhost:5000"
    sts = "http://localhost:5000"
    iam = "http://localhost:5000"
  }
}
