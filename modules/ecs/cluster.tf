locals {
  cluster_name                 = var.cluster_name != null ? var.cluster_name : "${var.project_name}-${var.environment}-ecs-cluster"
  capacity_provider_name       = var.capacity_provider_name != null ? var.capacity_provider_name : "${local.cluster_name}-capacity-provider"
  effective_capacity_providers = length(var.capacity_providers) > 0 ? var.capacity_providers : [aws_ecs_capacity_provider.this.name]
  effective_default_capacity_provider = var.default_capacity_provider != null ? var.default_capacity_provider : (
    length(var.capacity_providers) > 0 ? var.capacity_providers[0] : aws_ecs_capacity_provider.this.name
  )
  ecs_ami_architecture = "arm64"
}

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = var.container_insights_enabled ? "enabled" : "disabled"
  }

  tags = merge(var.tags, {
    Name        = local.cluster_name
    Environment = var.environment
    Project     = var.project_name
  })
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.project_name}-${var.environment}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ecs-instance-role"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.project_name}-${var.environment}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_security_group" "ecs_instances" {
  name        = "${var.project_name}-${var.environment}-ecs-instances"
  description = "Security group for ECS instances"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    description = "Allow ECS instance HTTPS egress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow ECS instance HTTP egress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow ECS instance DNS over UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow ECS instance DNS over TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # PostgreSQL egress is owned by the standalone rule in database.tf. The AWS
  # provider otherwise treats that rule as an extra inline rule and removes it.
  lifecycle {
    ignore_changes = [egress]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ecs-instances"
  })
}


data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-${local.ecs_ami_architecture}-ebs"]
  }
}

resource "aws_launch_template" "ecs" {
  name_prefix            = "${var.project_name}-${var.environment}-ecs-"
  image_id               = data.aws_ami.ecs_optimized.id
  instance_type          = var.ec2_instance_type
  vpc_security_group_ids = [aws_security_group.ecs_instances.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.project_name}-${var.environment}-ecs-instance"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ecs-launch-template"
  })
}

resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project_name}-${var.environment}-ecs-asg"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_capacity
  max_size            = var.max_capacity
  desired_capacity    = var.desired_capacity

  launch_template {
    id      = aws_launch_template.ecs.id
    version = aws_launch_template.ecs.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    triggers = ["tag"]
    preferences {
      min_healthy_percentage = 100
      instance_warmup        = 300
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-ecs-asg"
    propagate_at_launch = false
  }
  tag {
    key                 = "AutoScalingGroup"
    value               = "${var.project_name}-${var.environment}-ecs-asg"
    propagate_at_launch = true
  }
  dynamic "tag" {
    for_each = var.asg_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_ecs_capacity_provider" "this" {
  name = local.capacity_provider_name

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }

    managed_termination_protection = "DISABLED"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ecs-capacity-provider"
  })
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = local.effective_capacity_providers

  default_capacity_provider_strategy {
    capacity_provider = local.effective_default_capacity_provider
    weight            = var.default_capacity_provider_weight
    base              = var.default_capacity_provider_base
  }
}
