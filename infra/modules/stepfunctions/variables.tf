variable "name_prefix" { type = string }
variable "environment" { type = string }
variable "glue_job_names" {
  type = object({
    bronze = string
    silver = string
    gold   = string
  })
}
variable "redshift_workgroup_name" { type = string }
variable "redshift_database_name" { type = string }
variable "redshift_role_arn" { type = string }
variable "gold_bucket_name" { type = string }
variable "enable_schedule" { type = bool }
variable "schedule_expression" { type = string }
variable "schedule_timezone" { type = string }
