data "aws_ecs_task_definition" "web" {
  task_definition = aws_ecs_task_definition.web.arn
}

resource "aws_ecs_service" "web" {
  name            = local.service_name
  cluster         = var.cluster_name
  task_definition = data.aws_ecs_task_definition.web.arn
  desired_count   = var.desired_count
  launch_type     = "EC2"

  force_new_deployment = true

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  tags = merge(var.tags, {
    Name        = local.service_name
    Environment = var.environment
    Project     = var.project_name
  })
}
