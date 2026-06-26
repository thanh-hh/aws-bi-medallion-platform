#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-dev}"
REGION="${2:-us-east-1}"
FILE_PATH="${3:-sample_data/Data.xlsx}"
KEY="${4:-incoming/Data.xlsx}"

BUCKET=$(aws ssm get-parameter \
  --name "/bi-platform/aws-bi-medallion/${ENV_NAME}/buckets/bronze" \
  --region "$REGION" \
  --query 'Parameter.Value' \
  --output text)

aws s3 cp "$FILE_PATH" "s3://${BUCKET}/${KEY}" --region "$REGION"
echo "Uploaded to s3://${BUCKET}/${KEY}"
