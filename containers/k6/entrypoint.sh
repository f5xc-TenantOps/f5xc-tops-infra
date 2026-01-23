#!/bin/sh
set -e

# Upload results to S3 after test completes
upload_results() {
    if [ -f /tmp/results.json ] && [ -n "$RESULTS_BUCKET" ]; then
        TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
        aws s3 cp /tmp/results.json "s3://${RESULTS_BUCKET}/results-${TIMESTAMP}.json"
        echo "Results uploaded to s3://${RESULTS_BUCKET}/results-${TIMESTAMP}.json"
    fi
}

# Trap to upload results on exit
trap upload_results EXIT

# Run k6 with all passed arguments
exec k6 "$@"
