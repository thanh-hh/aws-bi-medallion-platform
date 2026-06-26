locals {
  scripts = {
    bronze = "01_bronze_ingest.py"
    silver = "02_silver_transform.py"
    gold   = "03_gold_model.py"
  }

  common_args = {
    "--BRONZE_BUCKET" = var.bronze_bucket_name
    "--SILVER_BUCKET" = var.silver_bucket_name
    "--GOLD_BUCKET"   = var.gold_bucket_name
    "--ENV"           = var.environment
    "--job-language"  = "python"
    "--additional-python-modules" = "pandas==2.2.2,openpyxl==3.1.5,pyarrow==16.1.0,s3fs==2024.6.1"
  }
}

resource "aws_s3_object" "glue_scripts" {
  for_each = local.scripts

  bucket      = var.artifacts_bucket_name
  key         = "glue/${each.value}"
  source      = "${path.root}/../etl/glue/${each.value}"
  source_hash = filemd5("${path.root}/../etl/glue/${each.value}")
  kms_key_id  = var.kms_key_arn
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "glue" {
  name               = "${var.name_prefix}-glue-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "glue_data" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      var.bronze_bucket_arn,
      "${var.bronze_bucket_arn}/*",
      var.silver_bucket_arn,
      "${var.silver_bucket_arn}/*",
      var.gold_bucket_arn,
      "${var.gold_bucket_arn}/*",
      var.artifacts_bucket_arn,
      "${var.artifacts_bucket_arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_policy" "glue_data" {
  name   = "${var.name_prefix}-glue-data-policy"
  policy = data.aws_iam_policy_document.glue_data.json
}

resource "aws_iam_role_policy_attachment" "glue_data" {
  role       = aws_iam_role.glue.name
  policy_arn = aws_iam_policy.glue_data.arn
}

resource "aws_glue_catalog_database" "bronze" {
  name = replace("${var.name_prefix}_bronze", "-", "_")
}

resource "aws_glue_catalog_database" "silver" {
  name = replace("${var.name_prefix}_silver", "-", "_")
}

resource "aws_glue_catalog_database" "gold" {
  name = replace("${var.name_prefix}_gold", "-", "_")
}

resource "aws_glue_job" "bronze" {
  name     = "${var.name_prefix}-bronze-ingest"
  role_arn = aws_iam_role.glue.arn
  glue_version = "4.0"
  max_capacity = 1
  timeout      = 20

  command {
    name            = "pythonshell"
    python_version  = "3.9"
    script_location = "s3://${var.artifacts_bucket_name}/${aws_s3_object.glue_scripts["bronze"].key}"
  }

  default_arguments = merge(local.common_args, {
    "--JOB_LAYER" = "bronze"
  })
}

resource "aws_glue_job" "silver" {
  name     = "${var.name_prefix}-silver-transform"
  role_arn = aws_iam_role.glue.arn
  glue_version = "4.0"
  max_capacity = 1
  timeout      = 20

  command {
    name            = "pythonshell"
    python_version  = "3.9"
    script_location = "s3://${var.artifacts_bucket_name}/${aws_s3_object.glue_scripts["silver"].key}"
  }

  default_arguments = merge(local.common_args, {
    "--JOB_LAYER" = "silver"
  })
}

resource "aws_glue_job" "gold" {
  name     = "${var.name_prefix}-gold-model"
  role_arn = aws_iam_role.glue.arn
  glue_version = "4.0"
  max_capacity = 1
  timeout      = 20

  command {
    name            = "pythonshell"
    python_version  = "3.9"
    script_location = "s3://${var.artifacts_bucket_name}/${aws_s3_object.glue_scripts["gold"].key}"
  }

  default_arguments = merge(local.common_args, {
    "--JOB_LAYER" = "gold"
  })
}
