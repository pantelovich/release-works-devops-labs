terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_partition" "current" {}

locals {
  registry = "${var.account_id}.dkr.ecr.${var.region}.${data.aws_partition.current.dns_suffix}"
  repo_arn = "arn:${data.aws_partition.current.partition}:ecr:${var.region}:${var.account_id}:repository/${var.name}"
  releases = { v1 = "healthy", v2 = "unhealthy" }
}

resource "aws_cloudwatch_log_group" "lab" {
  name              = "/ecs/${var.name}"
  retention_in_days = 1
}

resource "aws_iam_role" "execution" {
  name = "${var.name}-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.account_id }
        ArnLike = {
          "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:ecs:${var.region}:${var.account_id}:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "execution" {
  name = "lab-image-and-logs"
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "ecr:GetAuthorizationToken", Resource = "*" },
      {
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
        Resource = local.repo_arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${trimsuffix(aws_cloudwatch_log_group.lab.arn, ":*")}:log-stream:*"
      }
    ]
  })
}

resource "aws_ecs_cluster" "lab" {
  name = var.name
}

resource "aws_ecs_task_definition" "release" {
  for_each = local.releases

  family                   = "${var.name}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "api"
    image     = "${local.registry}/${var.name}@${var.image_digest}"
    essential = true
    environment = [
      { name = "RELEASE_VERSION", value = each.key },
      { name = "RELEASE_HEALTH", value = each.value }
    ]
    healthCheck = {
      command     = ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2)"]
      interval    = 10
      timeout     = 3
      retries     = 3
      startPeriod = 10
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.lab.name
        awslogs-region        = var.region
        awslogs-stream-prefix = each.key
      }
    }
  }])
}

resource "aws_ecs_service" "lab" {
  name                               = var.name
  cluster                            = aws_ecs_cluster.lab.id
  task_definition                    = aws_ecs_task_definition.release[var.release].arn
  desired_count                      = 1
  launch_type                        = "FARGATE"
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Observe rollout and rollback separately from plans and applies.
  wait_for_steady_state = false
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [var.subnet_id]
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  depends_on = [aws_iam_role_policy.execution]
}
