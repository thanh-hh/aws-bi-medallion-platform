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
  value = module.redshift.workgroup_name
}

output "redshift_database_name" {
  value = module.redshift.database_name
}

output "state_machine_arn" {
  value = module.stepfunctions.state_machine_arn
}
