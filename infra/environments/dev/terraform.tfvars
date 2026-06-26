project_name = "aws-bi-medallion"
environment  = "dev"
aws_region   = "us-east-1"

create_buckets = true

enable_schedule = false
schedule_expression = "cron(0 7 * * ? *)"
schedule_timezone   = "Asia/Ho_Chi_Minh"

redshift_base_capacity = 4
redshift_monthly_rpu_hours = 8

vpc_cidr = "10.60.0.0/16"
alert_email = ""

extra_tags = {
  Owner = "data-platform"
}
