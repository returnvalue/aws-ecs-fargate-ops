# AWS provider configuration for LocalStack
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    ec2            = "http://localhost:4566"
    ecs            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    applicationautoscaling = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}

# VPC: Network isolation for our Fargate tasks
resource "aws_vpc" "ecs_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "ecs-ops-vpc" }
}

# Subnets: Multi-AZ setup for container availability
resource "aws_subnet" "ecs_subnet_a" {
  vpc_id            = aws_vpc.ecs_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "ecs_subnet_b" {
  vpc_id            = aws_vpc.ecs_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

# ECS Cluster: Logical group for our Fargate services
resource "aws_ecs_cluster" "ops_cluster" {
  name = "sysops-fargate-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# IAM Role: ECS Task Execution Role (Allows ECS to pull images and write logs)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition: Blueprint for our containerized application
resource "aws_ecs_task_definition" "web_task" {
  family                   = "sysops-web-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name  = "web-server"
    image = "nginx:latest"
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
  }])
}

# ECS Service: Manages the lifecycle of our tasks
resource "aws_ecs_service" "web_service" {
  name            = "sysops-web-service"
  cluster         = aws_ecs_cluster.ops_cluster.id
  task_definition = aws_ecs_task_definition.web_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.ecs_subnet_a.id, aws_subnet.ecs_subnet_b.id]
    assign_public_ip = true
  }
}

# App Autoscaling Target: Connects scaling to our ECS service
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.ops_cluster.name}/${aws_ecs_service.web_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# App Autoscaling Policy: Scales based on CPU utilization
resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Outputs: Key identifiers for the ECS operations
output "cluster_name" {
  value = aws_ecs_cluster.ops_cluster.name
}

output "service_name" {
  value = aws_ecs_service.web_service.name
}
