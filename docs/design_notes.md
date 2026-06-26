# Design notes

## Why Step Functions + Glue instead of local scripts?

Local scripts are acceptable for one-time demos, but production ETL needs orchestration, retry, monitoring, IAM, and a clear execution history. Here, Glue runs the transformation code and Step Functions controls the order, retries, and Redshift load steps.

## Why Redshift Serverless?

For a BI warehouse layer, Redshift gives SQL tables, workload isolation, and a clear serving layer for BI tools. This repo uses Serverless to avoid cluster administration. In dev, the RPU capacity and usage limit are intentionally small.

## Medallion layers

- Bronze: original source and raw sheet splits.
- Silver: typed and cleaned tables.
- Gold: joined BI mart ready for Redshift/QuickSight.

## Security baseline

- S3 public access block.
- TLS-only S3 bucket policy.
- KMS encryption for S3 and Redshift.
- Private Redshift workgroup.
- S3 Gateway VPC endpoint for private COPY/UNLOAD traffic.
- IAM roles split by service.
- GitHub Actions uses OIDC, not long-lived access keys.

## Bucket existence

Terraform can be idempotent only for resources it manages in state. If a bucket already exists outside Terraform, choose one:

1. Import it:

```bash
terraform import 'module.storage.aws_s3_bucket.this["bronze"]' existing-bucket-name
```

2. Or set `create_buckets=false` and provide `existing_bucket_names` in the environment tfvars.

The repo does not use an external "check if bucket exists" hack inside Terraform because that weakens plan determinism.
