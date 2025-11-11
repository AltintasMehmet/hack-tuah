locals {
  tags = merge(var.tags, {
    "Environment" = var.environment,
    "Module"      = "database",
    "Name"        = var.name
  })

  user_data = templatefile("${path.module}/templates/database.sh", {
    environment             = var.environment
    db_username             = var.db_username
    db_password             = var.db_password
    enable_cloudwatch_agent = var.enable_cloudwatch_agent
  })
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

resource "aws_security_group" "db" {
  name        = "${var.name}-${var.environment}-db"
  description = "Database security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    "Name" = "${var.name}-${var.environment}-db-sg"
  })
}

resource "aws_instance" "db" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.db.id]
  associate_public_ip_address = false
  user_data                   = base64encode(local.user_data)

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(local.tags, {
    "Name" = "${var.name}-${var.environment}-db"
    "Tier" = "database"
  })
}

resource "aws_ebs_volume" "data" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = var.volume_size
  type              = var.volume_type

  tags = merge(local.tags, {
    "Name" = "${var.name}-${var.environment}-db-data"
  })
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.db.id
}

resource "aws_iam_role" "backup" {
  name               = "${var.name}-${var.environment}-db-backup"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

data "aws_iam_policy_document" "backup_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_backup_vault" "this" {
  name = "${var.name}-${var.environment}-vault"

  tags = merge(local.tags, {
    "Name" = "${var.name}-${var.environment}-vault"
  })
}

resource "aws_backup_plan" "this" {
  name = "${var.name}-${var.environment}-plan"

  rule {
    rule_name         = "${var.environment}-daily"
    target_vault_name = aws_backup_vault.this.name
    schedule          = "cron(0 3 * * ? *)"
    lifecycle {
      delete_after = var.backup_retention_days
    }
  }

  tags = local.tags
}

resource "aws_backup_selection" "this" {
  name         = "${var.environment}-db"
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = aws_iam_role.backup.arn
  resources    = [aws_instance.db.arn]
}
