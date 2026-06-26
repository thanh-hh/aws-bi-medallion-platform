project_name = "aws-bi-medallion"
environment  = "prod"
aws_region   = "us-east-1"

create_buckets = true

enable_schedule = true
schedule_expression = "cron(0 7 * * ? *)"
schedule_timezone   = "Asia/Ho_Chi_Minh"

redshift_base_capacity = 4
redshift_monthly_rpu_hours = 64

vpc_cidr = "10.62.0.0/16"
alert_email = ""

extra_tags = {
  Owner = "data-platform"
}
