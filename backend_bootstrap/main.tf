# ---------------------------------------------------------------------------
# Backend bootstrap — creates the S3 bucket that stores the root stack's
# remote state. Run this ONCE, before the root stack.
#
# This stack keeps its own state LOCAL (it can't store state in a bucket that
# doesn't exist yet), so there is no backend "s3" block here.
#
# State locking uses S3 natively (use_lockfile), so no DynamoDB table is
# needed — that's why this requires Terraform >= 1.10.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Component = "backend-bootstrap"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "logicmatrix"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "state" {
  bucket = lower("${var.project_name}-terraform")

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket_name" {
  value = aws_s3_bucket.state.bucket
}

# Paste this into the root stack's terraform {} block, then run `terraform init`.
output "backend_block" {
  description = "Ready-to-paste backend configuration for the root stack"
  value       = <<-EOT
    backend "s3" {
      bucket               = "${aws_s3_bucket.state.id}"
      workspace_key_prefix = "${var.project_name}"
      key                  = "terraform.tfstate"
      region               = "${var.aws_region}"
      use_lockfile         = true
    }
  EOT
}
