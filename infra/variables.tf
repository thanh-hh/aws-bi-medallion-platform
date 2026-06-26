variable "project_name" {
  description = "Project name used in resource names."
  type        = string
  default     = "aws-bi-medallion"
}

variable "environment" {
  description = "Deployment environment: dev, uat, prod."
  type        = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be dev, uat, or prod."
  }
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "create_buckets" {
  description = "If true, Terraform creates S3 medallion buckets. If false, existing_bucket_names must be provided."
  type        = bool
  default     = true
}

variable "existing_bucket_names" {
  description = "Existing buckets to use when create_buckets=false."
  type = object({
    bronze    = optional(string)
    silver    = optional(string)
    gold      = optional(string)
    artifacts = optional(string)
    logs      = optional(string)
  })
  default = {}
}

variable "enable_schedule" {
  description = "Create daily EventBridge Scheduler for the Step Functions pipeline."
  type        = bool
  default     = false
}

variable "schedule_expression" {
  description = "EventBridge Scheduler expression."
  type        = string
  default     = "cron(0 7 * * ? *)"
}

variable "schedule_timezone" {
  description = "Timezone for schedule."
  type        = string
  default     = "Asia/Ho_Chi_Minh"
}

variable "redshift_base_capacity" {
  description = "Redshift Serverless base capacity in RPUs. Keep low for dev."
  type        = number
  default     = 4
}

variable "redshift_monthly_rpu_hours" {
  description = "Usage limit in RPU-hours per month."
  type        = number
  default     = 8
}

variable "vpc_cidr" {
  description = "CIDR for analytics VPC."
  type        = string
  default     = "10.60.0.0/16"
}

variable "alert_email" {
  description = "Optional email for SNS alerts."
  type        = string
  default     = ""
}

variable "extra_tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}
