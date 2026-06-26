# AWS BI Medallion Platform - Terraform + Step Functions + Redshift

This repo is a deployable BI/data platform scaffold for **dev -> uat -> prod**.

It is intentionally designed as a real pipeline, not a collection of local scripts:

- Terraform provisions all infrastructure.
- S3 is split into medallion layers: **bronze**, **silver**, **gold**.
- ETL runs as AWS Glue Python Shell jobs.
- AWS Step Functions orchestrates the ETL jobs and Redshift load steps.
- Redshift Serverless is the BI warehouse layer.
- Security is handled with KMS, S3 public-block, TLS-only bucket policies, private Redshift, IAM roles, VPC endpoints, and environment-separated names.
- GitHub Actions deploys the same code to `dev`, `uat`, and `prod` using environment tfvars.

## Target Architecture

```text
GitHub Actions / Terraform
        |
        v
+-------------------+       +----------------------+       +----------------------+
| S3 Bronze         |  -->  | S3 Silver            |  -->  | S3 Gold              |
| raw / landed data |       | cleaned typed data   |       | BI marts             |
+-------------------+       +----------------------+       +----------------------+
        ^                             ^                              |
        |                             |                              v
        |                    +----------------+              +--------------------+
        |                    | AWS Glue Jobs  |              | Redshift Serverless|
        |                    +----------------+              +--------------------+
        |                             ^                              |
        |                             |                              v
        +---------------------+ AWS Step Functions +----------> QuickSight / BI
                              + EventBridge Scheduler
```

## Environment model

```text
infra/environments/dev/terraform.tfvars
infra/environments/uat/terraform.tfvars
infra/environments/prod/terraform.tfvars
```

Each environment has its own resource names, state key, tags, Redshift namespace/workgroup, S3 buckets, and pipeline schedule.

## First-time setup

### 1. Create Terraform remote state buckets

Terraform itself cannot store its state in a bucket that it has not created yet, so bootstrap state once per AWS account/region:

```bash
bash scripts/bootstrap_tf_state.sh us-east-1 aws-bi-platform
```

This creates:

```text
s3://aws-bi-platform-tfstate-<account-id>-us-east-1
```

### 2. Edit backend files

Update these files with your AWS account id and region:

```text
infra/environments/dev/backend.hcl
infra/environments/uat/backend.hcl
infra/environments/prod/backend.hcl
```

### 3. Deploy dev

```bash
cd infra
terraform init -backend-config=environments/dev/backend.hcl
terraform plan  -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

### 4. Upload sample data to the bronze bucket

```bash
bash scripts/upload_sample_data.sh dev us-east-1 sample_data/Data.xlsx
```

### 5. Start the pipeline manually

```bash
bash scripts/start_pipeline.sh dev us-east-1 incoming/Data.xlsx
```

## GitHub Actions deployment

This repo uses OIDC. Do not store long-lived AWS access keys in GitHub.

Required GitHub secrets:

```text
AWS_ROLE_ARN_DEV
AWS_ROLE_ARN_UAT
AWS_ROLE_ARN_PROD
AWS_REGION
```

Manual deployment:

```text
Actions -> Deploy Infra -> choose environment -> Run workflow
```

Manual ETL run:

```text
Actions -> Run Pipeline -> choose environment + input_key -> Run workflow
```

## Idempotency design

The platform is idempotent at multiple levels:

1. **Infrastructure**: Terraform manages resources by state. Re-running `terraform apply` should produce no changes unless code/tfvars change.
2. **Buckets**: deterministic names per `project_name + env + account_id + region`.
3. **Existing buckets**: Terraform cannot magically skip unmanaged existing buckets. This solution supports two safe modes:
   - `create_buckets = true`: Terraform creates and owns buckets.
   - `create_buckets = false`: provide existing bucket names and Terraform will reference them.
   - If you want Terraform to manage an existing bucket, import it into state first.
4. **ETL partitions**: Glue jobs write to `run_date=YYYY-MM-DD` paths and clear that partition before writing, so reruns do not duplicate output.
5. **Redshift load**: Gold writes both historical `run_date=...` and idempotent `current/` output. Step Functions executes `CREATE IF NOT EXISTS`, then `TRUNCATE + COPY` from `current/`. Rerun = same final result, not duplicated rows.
6. **Multi-env**: dev/uat/prod have separate state files and separate AWS resource names.

## ADF mapping

| Azure Data Factory | This AWS solution |
|---|---|
| Pipeline | Step Functions state machine |
| Schedule Trigger | EventBridge Scheduler |
| Copy Activity | Glue Bronze job / S3 write |
| Mapping Data Flow | Glue Silver/Gold jobs |
| Stored Procedure Activity | Redshift Data API task in Step Functions |
| Dataset | S3 path / Glue catalog / Redshift table |
| Linked Service | IAM role / VPC endpoint / Redshift workgroup |
| Monitor tab | Step Functions execution history + CloudWatch logs |
| ADLS Gen2 medallion | S3 bronze/silver/gold buckets |
| Synapse dedicated SQL pool | Redshift Serverless |

## What to explain in an interview

> I separated infrastructure deployment from daily ETL. Terraform deploys S3 medallion storage, IAM, KMS, VPC endpoints, Step Functions, Glue jobs, and Redshift Serverless. The ETL is not a local script; it is orchestrated by Step Functions. Bronze ingests the source file, Silver normalizes schema and data types, Gold builds BI marts, then Redshift loads the mart using the Data API. The same Terraform code is promoted across dev, uat, and prod using environment tfvars and remote state.

## Folder layout

```text
.github/workflows/             CI/CD deployment and pipeline trigger
etl/glue/                      Glue ETL job source code
infra/                         Terraform root module
infra/modules/storage/         S3 medallion buckets + security
infra/modules/network/         VPC, private subnets, endpoints, SG
infra/modules/glue/            Glue jobs, catalog, IAM
infra/modules/stepfunctions/   Orchestration + schedule
infra/modules/redshift/        Redshift Serverless + IAM + secret
infra/modules/observability/   CloudWatch/SNS cost and failure alerts
redshift/sql/                  SQL templates used by Step Functions
sample_data/                   Example Excel source file
scripts/                       Bootstrap / upload sample / start execution only
```

## Important warning

For a $100 AWS credit account, keep `enable_redshift = true` only while testing. Redshift Serverless can cost money if left running. Use the low `redshift_monthly_rpu_hours` limit in dev.
