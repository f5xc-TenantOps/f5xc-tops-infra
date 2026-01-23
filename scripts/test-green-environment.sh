#!/bin/bash
# scripts/test-green-environment.sh
# Test Green environment with synthetic checks

set -e

REGION="us-east-1"

echo "=== Testing Green Environment ==="
echo ""

# Test 1: Verify DynamoDB tables exist
echo "1. Checking DynamoDB tables..."
for table in tops-job-state-v2 tops-udf-lab-deployment-state-v2 tops-udf-lab-config-v2; do
    if aws dynamodb describe-table --table-name "${table}" --region "${REGION}" > /dev/null 2>&1; then
        echo "   ✓ ${table}"
    else
        echo "   ✗ ${table} (not found)"
    fi
done
echo ""

# Test 2: Verify SQS queues exist
echo "2. Checking SQS queues..."
for queue in tops-udf-queue-v2 tops-udf-dlq-v2; do
    if aws sqs get-queue-url --queue-name "${queue}" --region "${REGION}" > /dev/null 2>&1; then
        echo "   ✓ ${queue}"
    else
        echo "   ✗ ${queue} (not found)"
    fi
done
echo ""

# Test 3: Verify S3 buckets exist
echo "3. Checking S3 buckets..."
for bucket in tops-deployment-state-v2 tops-lambda-bucket-v2; do
    if aws s3api head-bucket --bucket "${bucket}" 2>/dev/null; then
        echo "   ✓ ${bucket}"
    else
        echo "   ✗ ${bucket} (not found)"
    fi
done
echo ""

# Test 4: Verify Lambda functions exist
echo "4. Checking Lambda functions..."
for func in tops-udf-dispatch-v2 tops-udf-worker-v2 tops-ns-create-v2 tops-ns-remove-v2 tops-user-create-v2 tops-user-remove-v2; do
    if aws lambda get-function --function-name "${func}" --region "${REGION}" > /dev/null 2>&1; then
        echo "   ✓ ${func}"
    else
        echo "   ✗ ${func} (not found)"
    fi
done
echo ""

# Test 5: Verify IAM roles exist
echo "5. Checking IAM roles..."
for role in tops-lambda-execution-role-v2 tops-udf-worker-role-v2 tops-udf-dispatch-role-v2; do
    if aws iam get-role --role-name "${role}" > /dev/null 2>&1; then
        echo "   ✓ ${role}"
    else
        echo "   ✗ ${role} (not found)"
    fi
done
echo ""

echo "=== Green Environment Tests Complete ==="
