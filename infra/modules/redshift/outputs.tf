output "workgroup_name" { value = aws_redshiftserverless_workgroup.this.workgroup_name }
output "namespace_name" { value = aws_redshiftserverless_namespace.this.namespace_name }
output "database_name" { value = aws_redshiftserverless_namespace.this.db_name }
output "copy_role_arn" { value = aws_iam_role.copy.arn }
output "admin_secret_arn" { value = aws_secretsmanager_secret.admin.arn }
