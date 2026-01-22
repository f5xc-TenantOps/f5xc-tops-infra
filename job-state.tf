# job-state.tf
# DynamoDB table for unified job state tracking across all trigger sources

resource "aws_dynamodb_table" "job_state" {
  name         = "tops-job-state${var.environment == "prod" ? "" : "-${var.environment}"}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_execution_id"

  attribute {
    name = "job_execution_id"
    type = "S"
  }

  # GSI for querying by dep_id (UDF deployments only)
  # Note: Items without dep_id won't appear in this index (sparse index behavior)
  global_secondary_index {
    name            = "dep_id-index"
    hash_key        = "dep_id"
    projection_type = "ALL"
  }

  attribute {
    name = "dep_id"
    type = "S"
  }

  # GSI for querying by email
  global_secondary_index {
    name            = "email-index"
    hash_key        = "email"
    projection_type = "ALL"
  }

  attribute {
    name = "email"
    type = "S"
  }

  # TTL for automatic cleanup after 7 days
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = local.tags
}

output "job_state_table_name" {
  description = "Name of the job state DynamoDB table"
  value       = aws_dynamodb_table.job_state.name
}

output "job_state_table_arn" {
  description = "ARN of the job state DynamoDB table"
  value       = aws_dynamodb_table.job_state.arn
}
