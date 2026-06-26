#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-dev}"
REGION="${2:-us-east-1}"
INPUT_KEY="${3:-incoming/Data.xlsx}"
RUN_DATE="${4:-}"

if [ -z "$RUN_DATE" ]; then
  RUN_DATE=$(date +%Y-%m-%d)
fi

ARN=$(aws ssm get-parameter \
  --name "/bi-platform/aws-bi-medallion/${ENV_NAME}/stepfunctions/pipeline_arn" \
  --region "$REGION" \
  --query 'Parameter.Value' \
  --output text 2>/dev/null || true)

if [ -z "$ARN" ]; then
  ARN=$(aws ssm get-parameter \
    --name "/aws-bi-medallion/${ENV_NAME}/stepfunctions/pipeline_arn" \
    --region "$REGION" \
    --query 'Parameter.Value' \
    --output text)
fi

EXECUTION_NAME="manual-${ENV_NAME}-$(date +%Y%m%d%H%M%S)"
aws stepfunctions start-execution \
  --state-machine-arn "$ARN" \
  --name "$EXECUTION_NAME" \
  --input "{\"input_key\":\"${INPUT_KEY}\",\"run_date\":\"${RUN_DATE}\"}" \
  --region "$REGION"

echo "Started execution: $EXECUTION_NAME"
