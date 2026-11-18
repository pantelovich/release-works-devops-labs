terraform {
  required_version = ">= 1.11.2, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = "release-works-devops-labs"
      Environment = "training"
    }
  }
}

data "aws_partition" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  registry = "${var.account_id}.dkr.ecr.${var.region}.${data.aws_partition.current.dns_suffix}"
  repo_arn = "arn:${data.aws_partition.current.partition}:ecr:${var.region}:${var.account_id}:repository/${var.name}"
  releases = { v1 = "healthy", v2 = "unhealthy" }
}

resource "aws_vpc" "lab" {
  cidr_block           = "10.84.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}

resource "aws_subnet" "lab" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = aws_vpc.lab.cidr_block
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = var.name }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = var.name }
}

resource "aws_route_table" "lab" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
}

resource "aws_route_table_association" "lab" {
  subnet_id      = aws_subnet.lab.id
  route_table_id = aws_route_table.lab.id
}

resource "aws_security_group" "lab" {
  name        = var.name
  description = "No inbound traffic; HTTPS outbound for image pulls and logs"
  vpc_id      = aws_vpc.lab.id
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.lab.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Registry and log API access"
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
    subnets          = [aws_subnet.lab.id]
    security_groups  = [aws_security_group.lab.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_route_table_association.lab,
    aws_iam_role_policy.execution,
    aws_vpc_security_group_egress_rule.https,
  ]
}
