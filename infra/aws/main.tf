terraform {
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }

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

data "aws_availability_zones" "available" {
  state = "available"
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

module "release" {
  source = "./modules/ecs-release"

  account_id        = var.account_id
  region            = var.region
  name              = var.name
  image_digest      = var.image_digest
  release           = var.release
  subnet_id         = aws_subnet.lab.id
  security_group_id = aws_security_group.lab.id

  depends_on = [
    aws_route_table_association.lab,
    aws_vpc_security_group_egress_rule.https,
  ]
}
