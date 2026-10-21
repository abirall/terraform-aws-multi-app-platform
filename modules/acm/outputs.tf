output "certificate_arn" {
  value = aws_acm_certificate.wildcard.arn
}

output "domain_validation_records" {
  description = "CNAME records to create manually in the authoritative DNS provider"
  value = {
    for option in aws_acm_certificate.wildcard.domain_validation_options : option.domain_name => {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  }
}
