output "cluster" {
  value = module.release.cluster
}

output "service" {
  value = module.release.service
}

output "baseline_task_definition" {
  value = module.release.baseline_task_definition
}

output "candidate_task_definition" {
  value = module.release.candidate_task_definition
}

output "log_group" {
  value = module.release.log_group
}
