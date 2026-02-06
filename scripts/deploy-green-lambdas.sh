#!/bin/bash
# scripts/deploy-green-lambdas.sh
# Deploy Lambda code to Green (v2) functions

set -e

LAMBDA_BUCKET="tops-lambda-bucket-v2"
REGION="us-east-1"
JOB_WORKERS_DIR="${JOB_WORKERS_DIR:-/home/coder/f5xc-tops-job-workers}"

LAMBDAS=(
    # Crossplane-managed Lambdas
    "udf_dispatch"
    "udf_worker"
    "ns_create"
    "ns_remove"
    "user_create"
    "user_remove"
    # Step Functions pipeline Lambdas
    "fetch_job_config"
    "resource_orchestrator"
    "stream_to_stepfunction"
    "origin_pool_create"
    "http_lb_create"
    "waf_policy_create"
)

echo "=== Deploying Green Lambda Functions ==="

for lambda in "${LAMBDAS[@]}"; do
    echo "Packaging ${lambda}..."

    # Create temp directory
    TEMP_DIR=$(mktemp -d)

    # Copy lambda code
    cp -r "${JOB_WORKERS_DIR}/${lambda}"/* "${TEMP_DIR}/"

    # Copy shared module
    cp -r "${JOB_WORKERS_DIR}/shared" "${TEMP_DIR}/"

    # Create zip
    ZIP_FILE="${lambda}_v2.zip"
    (cd "${TEMP_DIR}" && zip -r "${ZIP_FILE}" . -x "*.pyc" -x "__pycache__/*")

    # Upload to S3
    echo "Uploading ${ZIP_FILE} to s3://${LAMBDA_BUCKET}/"
    aws s3 cp "${TEMP_DIR}/${ZIP_FILE}" "s3://${LAMBDA_BUCKET}/${ZIP_FILE}" --region "${REGION}"

    # Convert underscore to hyphen for function name
    FUNC_NAME="tops-${lambda//_/-}-v2"

    # Update Lambda function (if it exists)
    echo "Updating Lambda function ${FUNC_NAME}..."
    aws lambda update-function-code \
        --function-name "${FUNC_NAME}" \
        --s3-bucket "${LAMBDA_BUCKET}" \
        --s3-key "${ZIP_FILE}" \
        --region "${REGION}" 2>/dev/null || echo "  Function ${FUNC_NAME} may not exist yet - will be created by Crossplane"

    # Cleanup
    rm -rf "${TEMP_DIR}"

    echo "Done with ${lambda}"
    echo ""
done

echo "=== All Green Lambda functions deployed ==="
