locals {
  suffix = "${var.account_id}-${var.region}"

  created_names = {
    bronze    = "${var.name_prefix}-bronze-${local.suffix}"
    silver    = "${var.name_prefix}-silver-${local.suffix}"
    gold      = "${var.name_prefix}-gold-${local.suffix}"
    artifacts = "${var.name_prefix}-artifacts-${local.suffix}"
    logs      = "${var.name_prefix}-logs-${local.suffix}"
  }

  bucket_names = {
    bronze    = var.create_buckets ? local.created_names.bronze    : var.existing_bucket_names.bronze
    silver    = var.create_buckets ? local.created_names.silver    : var.existing_bucket_names.silver
    gold      = var.create_buckets ? local.created_names.gold      : var.existing_bucket_names.gold
    artifacts = var.create_buckets ? local.created_names.artifacts : var.existing_bucket_names.artifacts
    logs      = var.create_buckets ? local.created_names.logs      : var.existing_bucket_names.logs
  }
}

resource "aws_kms_key" "lake" {
  description             = "KMS key for ${var.name_prefix} data lake buckets"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "lake" {
  name          = "alias/${var.name_prefix}-lake"
  target_key_id = aws_kms_key.lake.key_id
}

resource "aws_s3_bucket" "this" {
  for_each = var.create_buckets ? local.bucket_names : {}
  bucket   = each.value
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = var.create_buckets ? aws_s3_bucket.this : {}

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = var.create_buckets ? aws_s3_bucket.this : {}

  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = var.create_buckets ? aws_s3_bucket.this : {}

  bucket = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.lake.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = var.create_buckets ? aws_s3_bucket.this : {}

  bucket = each.value.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

data "aws_iam_policy_document" "deny_insecure_transport" {
  for_each = var.create_buckets ? aws_s3_bucket.this : {}

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      each.value.arn,
      "${each.value.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "deny_insecure_transport" {
  for_each = var.create_buckets ? aws_s3_bucket.this : {}

  bucket = each.value.id
  policy = data.aws_iam_policy_document.deny_insecure_transport[each.key].json
}

resource "aws_s3_bucket_lifecycle_configuration" "bronze" {
  count  = var.create_buckets ? 1 : 0
  bucket = aws_s3_bucket.this["bronze"].id

  rule {
    id     = "expire-bronze-noncurrent"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
