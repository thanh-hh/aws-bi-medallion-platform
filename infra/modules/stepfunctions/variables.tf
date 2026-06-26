variable "name_prefix" { type = string }
variable "environment" { type = string }
variable "glue_job_names" {
  type = object({
    bronze = string
    silver = string
    gold   = string
  })
}
variable "enable_schedule" { type = bool }
variable "schedule_expression" { type = string }
variable "schedule_timezone" { type = string }


variable "enable_redshift" {
  description = "If true, Step Functions will run Redshift SQL steps after the Gold Glue job."
  type        = bool
  default     = false
}

variable "redshift_workgroup_name" {
  description = "Redshift Serverless workgroup name. Null when Redshift is disabled."
  type        = string
  nullable    = true
  default     = null
}

variable "redshift_database_name" {
  description = "Redshift database name. Null when Redshift is disabled."
  type        = string
  nullable    = true
  default     = null
}

variable "redshift_role_arn" {
  description = "IAM role ARN used by Redshift COPY. Null when Redshift is disabled."
  type        = string
  nullable    = true
  default     = null
}


variable "gold_bucket_name" {
  description = "Gold S3 bucket name."
  type        = string
}