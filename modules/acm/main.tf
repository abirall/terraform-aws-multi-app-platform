terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_acm_certificate" "wildcard" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = distinct(var.subject_alternative_names)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn = aws_acm_certificate.wildcard.arn

  timeouts {
    create = "60m"
  }
}
