provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_s3_bucket" "terraform-backend" {
  bucket = "terraform-backend"

  tags = {
    Name = "Terraform Backend"
  }
}

resource "aws_s3_bucket_acl" "s3-backend-acl" {
  bucket = aws_s3_bucket.terraform-backend.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "s3-backend-versioning" {
  bucket = aws_s3_bucket.terraform-backend.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Enabled"
  }
}

resource "aws_kms_key" "mykey" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3-backend-kms" {
  bucket = aws_s3_bucket.terraform-backend.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.mykey.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

