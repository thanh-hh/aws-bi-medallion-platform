output "bronze_bucket_name" {
  value = module.storage.bronze_bucket_name
}

output "silver_bucket_name" {
  value = module.storage.silver_bucket_name
}

output "gold_bucket_name" {
  value = module.storage.gold_bucket_name
}

output "redshift_workgroup_name" {
  value = var.enable_redshift ? module.redshift[0].workgroup_name : null
}

output "redshift_database_name" {
  value = var.enable_redshift ? module.redshift[0].database_name : null
}

output "state_machine_arn" {
  value = module.stepfunctions.state_machine_arn
}
