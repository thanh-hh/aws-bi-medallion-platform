output "job_names" {
  value = {
    bronze = aws_glue_job.bronze.name
    silver = aws_glue_job.silver.name
    gold   = aws_glue_job.gold.name
  }
}

output "role_arn" { value = aws_iam_role.glue.arn }
