terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }


  # Uncomment after running the backend_bootstrap stack, then `terraform init`
  # to migrate local state into S3. Fill <ACCOUNT_ID> from the bootstrap output.
  #
  backend "s3" {
    bucket               = "logicmatrix-terraform"
    workspace_key_prefix = "prod"
    key                  = "terraform.tfstate"
    region               = "us-east-1"
    use_lockfile         = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.global_tags
  }
}
