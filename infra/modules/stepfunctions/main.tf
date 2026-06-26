locals {
  create_sql = templatefile("${path.module}/../../../redshift/sql/create_mart.sql.tftpl", {})
  load_sql = templatefile("${path.module}/../../../redshift/sql/load_mart.sql.tftpl", {
    gold_bucket_name  = var.gold_bucket_name
    redshift_role_arn = var.redshift_role_arn
  })
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "sfn" {
  name               = "${var.name_prefix}-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "sfn" {
  statement {
    effect = "Allow"
    actions = [
      "glue:StartJobRun",
      "glue:GetJobRun",
      "glue:GetJobRuns",
      "glue:BatchStopJobRun"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "redshift-data:ExecuteStatement",
      "redshift-data:BatchExecuteStatement",
      "redshift-data:DescribeStatement",
      "redshift-data:GetStatementResult"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = ["redshift-serverless:GetCredentials"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "sfn" {
  name   = "${var.name_prefix}-sfn-policy"
  policy = data.aws_iam_policy_document.sfn.json
}

resource "aws_iam_role_policy_attachment" "sfn" {
  role       = aws_iam_role.sfn.name
  policy_arn = aws_iam_policy.sfn.arn
}

resource "aws_cloudwatch_log_group" "sfn" {
  name              = "/aws/vendedlogs/states/${var.name_prefix}-etl"
  retention_in_days = 30
}

resource "aws_sfn_state_machine" "etl" {
  name     = "${var.name_prefix}-etl-pipeline"
  role_arn = aws_iam_role.sfn.arn
  type     = "STANDARD"

  logging_configuration {
    include_execution_data = true
    level                  = "ALL"
    log_destination        = "${aws_cloudwatch_log_group.sfn.arn}:*"
  }

  definition = templatefile("${path.module}/state_machine.asl.json.tftpl", {
    bronze_job_name          = var.glue_job_names.bronze
    silver_job_name          = var.glue_job_names.silver
    gold_job_name            = var.glue_job_names.gold
    redshift_workgroup_name  = var.redshift_workgroup_name
    redshift_database_name   = var.redshift_database_name
    create_sql_json          = jsonencode(local.create_sql)
    load_sql_json            = jsonencode(local.load_sql)
  })
}

data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "scheduler" {
  count              = var.enable_schedule ? 1 : 0
  name               = "${var.name_prefix}-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
}

data "aws_iam_policy_document" "scheduler" {
  count = var.enable_schedule ? 1 : 0
  statement {
    effect    = "Allow"
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.etl.arn]
  }
}

resource "aws_iam_policy" "scheduler" {
  count  = var.enable_schedule ? 1 : 0
  name   = "${var.name_prefix}-scheduler-policy"
  policy = data.aws_iam_policy_document.scheduler[0].json
}

resource "aws_iam_role_policy_attachment" "scheduler" {
  count      = var.enable_schedule ? 1 : 0
  role       = aws_iam_role.scheduler[0].name
  policy_arn = aws_iam_policy.scheduler[0].arn
}

resource "aws_scheduler_schedule" "daily" {
  count = var.enable_schedule ? 1 : 0

  name                         = "${var.name_prefix}-daily-etl"
  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.schedule_timezone
  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_sfn_state_machine.etl.arn
    role_arn = aws_iam_role.scheduler[0].arn
    input    = jsonencode({ input_key = "incoming/Data.xlsx" })
  }
}
