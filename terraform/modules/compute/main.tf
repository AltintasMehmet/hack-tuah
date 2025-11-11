locals {
  base_tags = merge(var.tags, {
    "Environment" = var.environment,
    "Module"      = "compute",
    "Name"        = var.name
  })

  frontend_user_data = templatefile("${path.module}/templates/frontend.sh", {
    environment             = var.environment
    port                    = var.frontend_port
    enable_cloudwatch_agent = var.frontend_launch_template.enable_cloudwatch_agent
    environment_variables   = var.frontend_launch_template.environment_variables
  })

  api_user_data = templatefile("${path.module}/templates/api.sh", {
    environment             = var.environment
    port                    = var.api_port
    enable_cloudwatch_agent = var.api_launch_template.enable_cloudwatch_agent
    environment_variables   = var.api_launch_template.environment_variables
  })
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-${var.environment}-alb"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from the internet"
    from_port   = var.alb_listener_port
    to_port     = var.alb_listener_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    "Name" = "${var.name}-${var.environment}-alb-sg"
  })
}

resource "aws_security_group" "frontend" {
  name        = "${var.name}-${var.environment}-frontend"
  description = "Frontend instance security group"
  vpc_id      = var.vpc_id

  ingress {
    description      = "HTTP from ALB"
    from_port        = var.frontend_port
    to_port          = var.frontend_port
    protocol         = "tcp"
    security_groups  = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    "Name" = "${var.name}-${var.environment}-frontend-sg"
  })
}

resource "aws_security_group" "api" {
  name        = "${var.name}-${var.environment}-api"
  description = "API instance security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "API access from ALB"
    from_port       = var.api_port
    to_port         = var.api_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    "Name" = "${var.name}-${var.environment}-api-sg"
  })
}

resource "aws_lb" "this" {
  name               = substr("${var.name}-${var.environment}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
  idle_timeout       = var.alb_idle_timeout

  tags = merge(local.base_tags, {
    "Name" = "${var.name}-${var.environment}-alb"
  })
}

resource "aws_lb_target_group" "frontend" {
  name     = substr("${var.name}-${var.environment}-fe", 0, 32)
  port     = var.frontend_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = merge(local.base_tags, {
    "Name" = "${var.name}-${var.environment}-frontend-tg"
  })
}

resource "aws_lb_target_group" "api" {
  name     = substr("${var.name}-${var.environment}-api", 0, 32)
  port     = var.api_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/healthz"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = merge(local.base_tags, {
    "Name" = "${var.name}-${var.environment}-api-tg"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.alb_listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

resource "aws_iam_instance_profile" "frontend" {
  name = "${var.name}-${var.environment}-frontend"
  role = aws_iam_role.frontend.name
}

resource "aws_iam_role" "frontend" {
  name               = "${var.name}-${var.environment}-frontend"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

resource "aws_iam_instance_profile" "api" {
  name = "${var.name}-${var.environment}-api"
  role = aws_iam_role.api.name
}

resource "aws_iam_role" "api" {
  name               = "${var.name}-${var.environment}-api"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_launch_template" "frontend" {
  name_prefix   = "${var.name}-${var.environment}-frontend-"
  image_id      = var.frontend_launch_template.ami_id
  instance_type = var.frontend_launch_template.instance_type
  key_name      = var.frontend_launch_template.key_name
  user_data     = base64encode(local.frontend_user_data)

  iam_instance_profile {
    name = aws_iam_instance_profile.frontend.name
  }

  vpc_security_group_ids = [aws_security_group.frontend.id]

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.base_tags, {
      "Tier" = "frontend"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.base_tags, {
      "Tier" = "frontend"
    })
  }
}

resource "aws_launch_template" "api" {
  name_prefix   = "${var.name}-${var.environment}-api-"
  image_id      = var.api_launch_template.ami_id
  instance_type = var.api_launch_template.instance_type
  key_name      = var.api_launch_template.key_name
  user_data     = base64encode(local.api_user_data)

  iam_instance_profile {
    name = aws_iam_instance_profile.api.name
  }

  vpc_security_group_ids = [aws_security_group.api.id]

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.base_tags, {
      "Tier" = "api"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.base_tags, {
      "Tier" = "api"
    })
  }
}

resource "aws_autoscaling_group" "frontend" {
  name                      = "${var.name}-${var.environment}-frontend"
  desired_capacity          = var.frontend_launch_template.desired_capacity
  max_size                  = var.frontend_launch_template.max_size
  min_size                  = var.frontend_launch_template.min_size
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 120
  target_group_arns         = [aws_lb_target_group.frontend.arn]

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-${var.environment}-frontend"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "api" {
  name                      = "${var.name}-${var.environment}-api"
  desired_capacity          = var.api_launch_template.desired_capacity
  max_size                  = var.api_launch_template.max_size
  min_size                  = var.api_launch_template.min_size
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 120
  target_group_arns         = [aws_lb_target_group.api.arn]

  launch_template {
    id      = aws_launch_template.api.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-${var.environment}-api"
    propagate_at_launch = true
  }
}

