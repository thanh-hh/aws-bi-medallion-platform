resource "random_password" "admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "admin" {
  name                    = "${var.name_prefix}/redshift/admin"
  recovery_window_in_days = 7
  kms_key_id              = var.kms_key_arn
}

resource "aws_secretsmanager_secret_version" "admin" {
  secret_id = aws_secretsmanager_secret.admin.id
  secret_string = jsonencode({
    username = "adminuser"
    password = random_password.admin.result
  })
}

data "aws_iam_policy_document" "redshift_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["redshift.amazonaws.com", "redshift-serverless.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "copy" {
  name               = "${var.name_prefix}-redshift-copy-role"
  assume_role_policy = data.aws_iam_policy_document.redshift_assume.json
}

data "aws_iam_policy_document" "copy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      var.gold_bucket_arn,
      "${var.gold_bucket_arn}/*",
      var.silver_bucket_arn,
      "${var.silver_bucket_arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_policy" "copy" {
  name   = "${var.name_prefix}-redshift-copy-policy"
  policy = data.aws_iam_policy_document.copy.json
}

resource "aws_iam_role_policy_attachment" "copy" {
  role       = aws_iam_role.copy.name
  policy_arn = aws_iam_policy.copy.arn
}

resource "aws_redshiftserverless_namespace" "this" {
  namespace_name      = replace("${var.name_prefix}-ns", "_", "-")
  db_name             = "bidb"
  admin_username      = jsondecode(aws_secretsmanager_secret_version.admin.secret_string)["username"]
  admin_user_password = jsondecode(aws_secretsmanager_secret_version.admin.secret_string)["password"]
  kms_key_id          = var.kms_key_arn
  iam_roles           = [aws_iam_role.copy.arn]
  default_iam_role_arn = aws_iam_role.copy.arn
  log_exports         = ["userlog", "connectionlog", "useractivitylog"]
}

resource "aws_redshiftserverless_workgroup" "this" {
  namespace_name      = aws_redshiftserverless_namespace.this.namespace_name
  workgroup_name      = replace("${var.name_prefix}-wg", "_", "-")
  base_capacity       = var.base_capacity
  enhanced_vpc_routing = true
  publicly_accessible = false
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids

  config_parameter {
    parameter_key   = "enable_user_activity_logging"
    parameter_value = "true"
  }
}

resource "aws_redshiftserverless_usage_limit" "compute" {
  resource_arn  = aws_redshiftserverless_workgroup.this.arn
  usage_type    = "serverless-compute"
  amount        = var.monthly_rpu_hours_limit
  period        = "monthly"
  breach_action = "deactivate"
}
