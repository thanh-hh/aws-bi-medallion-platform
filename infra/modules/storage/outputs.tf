output "kms_key_arn" { value = aws_kms_key.lake.arn }

output "bronze_bucket_name" { value = local.bucket_names.bronze }
output "silver_bucket_name" { value = local.bucket_names.silver }
output "gold_bucket_name" { value = local.bucket_names.gold }
output "artifacts_bucket_name" { value = local.bucket_names.artifacts }
output "logs_bucket_name" { value = local.bucket_names.logs }

output "bronze_bucket_arn" { value = "arn:aws:s3:::${local.bucket_names.bronze}" }
output "silver_bucket_arn" { value = "arn:aws:s3:::${local.bucket_names.silver}" }
output "gold_bucket_arn" { value = "arn:aws:s3:::${local.bucket_names.gold}" }
output "artifacts_bucket_arn" { value = "arn:aws:s3:::${local.bucket_names.artifacts}" }
