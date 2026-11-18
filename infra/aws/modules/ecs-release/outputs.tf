output "cluster" {
  value = aws_ecs_cluster.lab.name
}

output "service" {
  value = aws_ecs_service.lab.name
}

output "baseline_task_definition" {
  value = aws_ecs_task_definition.release["v1"].arn
}

output "candidate_task_definition" {
  value = aws_ecs_task_definition.release["v2"].arn
}

output "log_group" {
  value = aws_cloudwatch_log_group.lab.name
}
