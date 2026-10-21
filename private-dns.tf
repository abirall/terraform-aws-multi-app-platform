resource "aws_route53_zone" "private" {
  name    = var.private_hosted_zone_name
  comment = "Private DNS namespace for ${var.project_name} ${var.environment} resources"

  vpc {
    vpc_id     = module.vpc.vpc_id
    vpc_region = var.aws_region
  }

  tags = merge(var.tags, {
    Name        = var.private_hosted_zone_name
    Environment = var.environment
    Project     = var.project_name
  })
}

resource "aws_route53_record" "postgres" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "postgres.${trimsuffix(var.private_hosted_zone_name, ".")}"
  type    = "CNAME"
  ttl     = 60
  records = [aws_db_instance.postgres.address]
}
