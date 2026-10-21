resource "aws_db_subnet_group" "postgres" {
  name        = "${var.project_name}-${var.environment}-postgres"
  description = "Isolated database subnets for PostgreSQL"
  subnet_ids  = module.vpc.database_subnet_ids

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Environment = var.environment
    Project     = var.project_name
  })
}

resource "aws_security_group" "postgres" {
  name        = "${var.project_name}-${var.environment}-postgres"
  description = "PostgreSQL access from approved ECS tasks"
  vpc_id      = module.vpc.vpc_id

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Environment = var.environment
    Project     = var.project_name
  })
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_ecs_instances" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = module.ecs.ecs_instance_security_group_id
  description                  = "PostgreSQL from ECS container instances"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
}

resource "aws_vpc_security_group_egress_rule" "ecs_instances_to_postgres" {
  security_group_id            = module.ecs.ecs_instance_security_group_id
  referenced_security_group_id = aws_security_group.postgres.id
  description                  = "PostgreSQL from ECS container instances"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_netbird_routing_peer" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_security_group.netbird_routing_peer.id
  description                  = "PostgreSQL from the NetBird routing peer"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
}

resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_type
  port           = var.db_port

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  backup_retention_period  = var.db_backup_retention_days
  copy_tags_to_snapshot    = true
  delete_automated_backups = false
  deletion_protection      = var.db_deletion_protection
  skip_final_snapshot      = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : (
    "${var.project_name}-${var.environment}-postgres-final"
  )

  auto_minor_version_upgrade = true
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade",
  ]

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Environment = var.environment
    Project     = var.project_name
  })
}
