locals {
  service_name = var.service_name != null ? var.service_name : "${var.project_name}-${var.environment}-portfolio"
  task_family  = var.task_family != null ? var.task_family : "${local.service_name}-task"

  environment_variables = [
    for name, value in var.container_environment : {
      name  = name
      value = value
    }
  ]

  secrets = [
    for name, value in var.secrets : {
      name      = name
      valueFrom = value
    }
  ]
}

resource "aws_cloudwatch_log_group" "portfolio" {
  name              = "/ecs/${local.service_name}"
  retention_in_days = var.log_retention_days
  tags = merge(var.tags, {
    Name        = local.service_name
    Environment = var.environment
    Project     = var.project_name
  })
}

resource "aws_iam_role" "task_execution" {
  name = "${local.service_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${local.service_name}-execution-role"
    Environment = var.environment
    Project     = var.project_name
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_iam_role_policy" "task_execution_secrets" {
  count = length(var.secrets) > 0 ? 1 : 0

  name = "${local.service_name}-secrets"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameters"]
        Resource = values(var.secrets)
      }
    ]
  })
}
