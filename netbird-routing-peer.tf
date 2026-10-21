
data "aws_ami" "ubuntu_arm64" {
  owners = ["099720109477"] # Canonical's verified AWS account.

  filter {
    name   = "image-id"
    values = [var.netbird_routing_peer_ami_id]
  }

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-arm64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  netbird_routing_peer_name = "${var.project_name}-${var.environment}-netbird-routing-peer"
}

resource "aws_security_group" "netbird_routing_peer" {
  name        = local.netbird_routing_peer_name
  description = "Private NetBird routing peer; interactive fallback access uses SSM"
  vpc_id      = module.vpc.vpc_id

  tags = merge(var.tags, {
    Name        = local.netbird_routing_peer_name
    Environment = var.environment
    Project     = var.project_name
  })
}

resource "aws_vpc_security_group_egress_rule" "netbird_routing_peer_all" {
  security_group_id = aws_security_group.netbird_routing_peer.id
  description       = "NetBird control, peer traffic, package installation, and AWS APIs"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_iam_role" "netbird_routing_peer" {
  name = local.netbird_routing_peer_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "netbird_routing_peer_ssm_core" {
  role       = aws_iam_role.netbird_routing_peer.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_ssm_parameter" "netbird_routing_peer_setup_key" {
  name        = "/${var.project_name}/${var.environment}/netbird/setup-key"
  description = "Reusable setup key for the NetBird routing-peer ASG"
  type        = "SecureString"
  value_wo    = var.netbird_routing_peer_setup_key

  # Increment this version when rotating the write-only setup key.
  value_wo_version = var.netbird_routing_peer_setup_key_version

  tags = merge(var.tags, {
    Name        = "${local.netbird_routing_peer_name}-setup-key"
    Environment = var.environment
    Project     = var.project_name
  })
}

resource "aws_iam_role_policy" "netbird_routing_peer_setup_key" {
  name = "${local.netbird_routing_peer_name}-setup-key"
  role = aws_iam_role.netbird_routing_peer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:GetParameter"
      Resource = aws_ssm_parameter.netbird_routing_peer_setup_key.arn
    }]
  })
}

resource "aws_iam_role_policy" "netbird_routing_peer_disable_source_dest_check" {
  name = "${local.netbird_routing_peer_name}-disable-source-dest-check"
  role = aws_iam_role.netbird_routing_peer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ec2:ModifyInstanceAttribute"
      Resource = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"
      Condition = {
        StringEquals = {
          "ec2:ResourceTag/Name" = local.netbird_routing_peer_name
        }
      }
    }]
  })
}

resource "aws_iam_instance_profile" "netbird_routing_peer" {
  name = local.netbird_routing_peer_name
  role = aws_iam_role.netbird_routing_peer.name
}

resource "aws_launch_template" "netbird_routing_peer" {
  name_prefix            = "${local.netbird_routing_peer_name}-"
  description            = "Ubuntu 26.04 LTS ARM64 NetBird routing peer"
  image_id               = data.aws_ami.ubuntu_arm64.id
  instance_type          = var.netbird_routing_peer_instance_type
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.netbird_routing_peer.name
  }

  vpc_security_group_ids = [aws_security_group.netbird_routing_peer.id]

  user_data = base64encode(templatefile("${path.module}/templates/netbird-routing-peer-cloud-config.yaml.tftpl", {
    netbird_peer_hostname            = local.netbird_routing_peer_name
    netbird_setup_key_parameter_name = aws_ssm_parameter.netbird_routing_peer_setup_key.name
    netbird_setup_key_version        = var.netbird_routing_peer_setup_key_version
    private_dns_zone_name            = trimsuffix(var.private_hosted_zone_name, ".")
    aws_region                       = var.aws_region
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  block_device_mappings {
    # Match the Canonical AMI root-device name. Using /dev/xvda here adds a
    # second EBS volume instead of overriding and encrypting the AMI root disk.
    device_name = "/dev/sda1"

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.netbird_routing_peer_root_volume_size
      volume_type           = "gp3"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name        = local.netbird_routing_peer_name
      Environment = var.environment
      Project     = var.project_name
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name        = "${local.netbird_routing_peer_name}-root"
      Environment = var.environment
      Project     = var.project_name
    })
  }
}

resource "aws_autoscaling_group" "netbird_routing_peer" {
  depends_on = [
    aws_iam_role_policy.netbird_routing_peer_disable_source_dest_check,
    aws_iam_role_policy.netbird_routing_peer_setup_key,
  ]

  name                = "${local.netbird_routing_peer_name}-asg"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [module.vpc.private_subnet_id]

  launch_template {
    id      = aws_launch_template.netbird_routing_peer.id
    version = aws_launch_template.netbird_routing_peer.latest_version
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 300
    }
  }

  dynamic "tag" {
    for_each = merge(var.tags, {
      Name        = local.netbird_routing_peer_name
      Environment = var.environment
      Project     = var.project_name
    })

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

data "aws_instances" "netbird_routing_peer" {
  depends_on = [aws_autoscaling_group.netbird_routing_peer]

  instance_state_names = ["pending", "running"]

  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.netbird_routing_peer.name]
  }
}
