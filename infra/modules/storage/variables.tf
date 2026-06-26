variable "project_name" { type = string }
variable "environment" { type = string }
variable "region" { type = string }
variable "account_id" { type = string }
variable "name_prefix" { type = string }
variable "create_buckets" { type = bool }
variable "existing_bucket_names" {
  type = object({
    bronze    = optional(string)
    silver    = optional(string)
    gold      = optional(string)
    artifacts = optional(string)
    logs      = optional(string)
  })
  default = {}
}
