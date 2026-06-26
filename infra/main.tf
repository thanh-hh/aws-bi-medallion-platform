module "network" {
  source      = "./modules/network"
  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
}

module "storage" {
  source                = "./modules/storage"
  project_name          = var.project_name
  environment           = var.environment
  region                = local.region
  account_id            = local.account_id
  name_prefix           = local.name_prefix
  create_buckets        = var.create_buckets
  existing_bucket_names = var.existing_bucket_names
}

module "redshift" {
  source                    = "./modules/redshift"
  name_prefix               = local.name_prefix
  environment               = var.environment
  subnet_ids                = module.network.private_subnet_ids
  security_group_ids        = [module.network.redshift_security_group_id]
  kms_key_arn               = module.storage.kms_key_arn
  gold_bucket_arn           = module.storage.gold_bucket_arn
  silver_bucket_arn         = module.storage.silver_bucket_arn
  base_capacity             = var.redshift_base_capacity
  monthly_rpu_hours_limit   = var.redshift_monthly_rpu_hours
}

module "glue" {
  source               = "./modules/glue"
  name_prefix          = local.name_prefix
  environment          = var.environment
  bronze_bucket_name   = module.storage.bronze_bucket_name
  silver_bucket_name   = module.storage.silver_bucket_name
  gold_bucket_name     = module.storage.gold_bucket_name
  artifacts_bucket_name= module.storage.artifacts_bucket_name
  bronze_bucket_arn    = module.storage.bronze_bucket_arn
  silver_bucket_arn    = module.storage.silver_bucket_arn
  gold_bucket_arn      = module.storage.gold_bucket_arn
  artifacts_bucket_arn = module.storage.artifacts_bucket_arn
  kms_key_arn          = module.storage.kms_key_arn
}

module "stepfunctions" {
  source                  = "./modules/stepfunctions"
  name_prefix             = local.name_prefix
  environment             = var.environment
  glue_job_names          = module.glue.job_names
  redshift_workgroup_name = module.redshift.workgroup_name
  redshift_database_name  = module.redshift.database_name
  redshift_role_arn       = module.redshift.copy_role_arn
  gold_bucket_name        = module.storage.gold_bucket_name
  enable_schedule         = var.enable_schedule
  schedule_expression     = var.schedule_expression
  schedule_timezone       = var.schedule_timezone
}

module "observability" {
  source        = "./modules/observability"
  name_prefix   = local.name_prefix
  alert_email   = var.alert_email
  state_machine_arn = module.stepfunctions.state_machine_arn
}

resource "aws_ssm_parameter" "bronze_bucket" {
  name  = "/aws-bi-medallion/${var.environment}/buckets/bronze"
  type  = "String"
  value = module.storage.bronze_bucket_name
}

resource "aws_ssm_parameter" "silver_bucket" {
  name  = "/aws-bi-medallion/${var.environment}/buckets/silver"
  type  = "String"
  value = module.storage.silver_bucket_name
}

resource "aws_ssm_parameter" "gold_bucket" {
  name  = "/aws-bi-medallion/${var.environment}/buckets/gold"
  type  = "String"
  value = module.storage.gold_bucket_name
}

resource "aws_ssm_parameter" "pipeline_arn" {
  name  = "/aws-bi-medallion/${var.environment}/stepfunctions/pipeline_arn"
  type  = "String"
  value = module.stepfunctions.state_machine_arn
}
