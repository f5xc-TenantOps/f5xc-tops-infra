# provisioning-workflow.tf
# Step Function workflow and supporting lambdas for TenantOps provisioning

# =============================================================================
# Lambda Functions for Provisioning Workflow
# =============================================================================

# fetch_job_config Lambda
data "aws_s3_object" "fetch_job_config_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "fetch_job_config${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_lambda_function" "fetch_job_config_lambda" {
  function_name    = "tops-fetch-job-config${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.utility_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = "fetch_job_config${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
  source_code_hash = data.aws_s3_object.fetch_job_config_zip.etag
  kms_key_arn      = aws_kms_key.lambda_encryption.arn

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      DEPLOYMENT_STATE_BUCKET = aws_s3_bucket.deployment_state.bucket
      JOB_STATE_TABLE         = aws_dynamodb_table.job_state.name
    }
  }

  tags = local.tags
}

# resource_orchestrator Lambda
data "aws_s3_object" "resource_orchestrator_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "resource_orchestrator${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_lambda_function" "resource_orchestrator_lambda" {
  function_name    = "tops-resource-orchestrator${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.provisioning_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = "resource_orchestrator${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
  source_code_hash = data.aws_s3_object.resource_orchestrator_zip.etag
  kms_key_arn      = aws_kms_key.lambda_encryption.arn

  timeout     = 300 # 5 minutes for orchestration
  memory_size = 256

  environment {
    variables = {
      DEPLOYMENT_STATE_BUCKET = aws_s3_bucket.deployment_state.bucket
      JOB_STATE_TABLE         = aws_dynamodb_table.job_state.name
      LAMBDA_PREFIX           = "tops-${var.environment == "prod" ? "" : "${var.environment}-"}"
    }
  }

  tags = local.tags
}

# origin_pool_create Lambda
data "aws_s3_object" "origin_pool_create_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "origin_pool_create${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_lambda_function" "origin_pool_create_lambda" {
  function_name    = "tops-origin-pool-create${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.utility_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = "origin_pool_create${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
  source_code_hash = data.aws_s3_object.origin_pool_create_zip.etag
  kms_key_arn      = aws_kms_key.lambda_encryption.arn

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      DEPLOYMENT_STATE_BUCKET = aws_s3_bucket.deployment_state.bucket
      JOB_STATE_TABLE         = aws_dynamodb_table.job_state.name
    }
  }

  tags = local.tags
}

# http_lb_create Lambda
data "aws_s3_object" "http_lb_create_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "http_lb_create${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_lambda_function" "http_lb_create_lambda" {
  function_name    = "tops-http-lb-create${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.utility_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = "http_lb_create${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
  source_code_hash = data.aws_s3_object.http_lb_create_zip.etag
  kms_key_arn      = aws_kms_key.lambda_encryption.arn

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      DEPLOYMENT_STATE_BUCKET = aws_s3_bucket.deployment_state.bucket
      JOB_STATE_TABLE         = aws_dynamodb_table.job_state.name
    }
  }

  tags = local.tags
}

# waf_policy_create Lambda
data "aws_s3_object" "waf_policy_create_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "waf_policy_create${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_lambda_function" "waf_policy_create_lambda" {
  function_name    = "tops-waf-policy-create${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.utility_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = "waf_policy_create${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
  source_code_hash = data.aws_s3_object.waf_policy_create_zip.etag
  kms_key_arn      = aws_kms_key.lambda_encryption.arn

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      DEPLOYMENT_STATE_BUCKET = aws_s3_bucket.deployment_state.bucket
      JOB_STATE_TABLE         = aws_dynamodb_table.job_state.name
    }
  }

  tags = local.tags
}

# =============================================================================
# IAM Role for Provisioning Lambdas (resource_orchestrator needs Lambda invoke)
# =============================================================================

resource "aws_iam_role" "provisioning_lambda_role" {
  name = "tops-provisioning-lambda-role${var.environment == "prod" ? "" : "-${var.environment}"}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_policy" "provisioning_lambda_policy" {
  name        = "tops-provisioning-lambda-policy${var.environment == "prod" ? "" : "-${var.environment}"}"
  description = "IAM Policy for provisioning workflow lambdas"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # CloudWatch Logs
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:CreateLogGroup"],
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/tops-*"
      },
      # SSM Parameters
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ],
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/*"
      },
      # S3 for deployment state
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.deployment_state.arn}/*"
      },
      # DynamoDB for job state
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ],
        Resource = [
          aws_dynamodb_table.job_state.arn,
          "${aws_dynamodb_table.job_state.arn}/index/*"
        ]
      },
      # Lambda invoke for resource orchestrator
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = [
          aws_lambda_function.origin_pool_create_lambda.arn,
          aws_lambda_function.http_lb_create_lambda.arn,
          aws_lambda_function.waf_policy_create_lambda.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "provisioning_lambda_attach" {
  role       = aws_iam_role.provisioning_lambda_role.name
  policy_arn = aws_iam_policy.provisioning_lambda_policy.arn
}

# =============================================================================
# Step Function State Machine
# =============================================================================

resource "aws_iam_role" "step_function_role" {
  name = "tops-provisioning-sfn-role${var.environment == "prod" ? "" : "-${var.environment}"}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "states.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_policy" "step_function_policy" {
  name        = "tops-provisioning-sfn-policy${var.environment == "prod" ? "" : "-${var.environment}"}"
  description = "IAM Policy for TenantOps provisioning Step Function"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # CloudWatch Logs for Step Function
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ],
        Resource = "*"
      },
      # Lambda invoke permissions
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = [
          aws_lambda_function.fetch_job_config_lambda.arn,
          aws_lambda_function.ns_create_lambda.arn,
          aws_lambda_function.user_create_lambda.arn,
          aws_lambda_function.resource_orchestrator_lambda.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "step_function_attach" {
  role       = aws_iam_role.step_function_role.name
  policy_arn = aws_iam_policy.step_function_policy.arn
}

resource "aws_sfn_state_machine" "provisioning_workflow" {
  name     = "tops-provisioning-workflow${var.environment == "prod" ? "" : "-${var.environment}"}"
  role_arn = aws_iam_role.step_function_role.arn

  definition = templatefile("${path.module}/stepfunction/provisioning-workflow.json", {
    FetchJobConfigLambdaArn      = aws_lambda_function.fetch_job_config_lambda.arn
    NsCreateLambdaArn            = aws_lambda_function.ns_create_lambda.arn
    UserCreateLambdaArn          = aws_lambda_function.user_create_lambda.arn
    ResourceOrchestratorLambdaArn = aws_lambda_function.resource_orchestrator_lambda.arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_function_logs.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "step_function_logs" {
  name              = "/aws/states/tops-provisioning-workflow${var.environment == "prod" ? "" : "-${var.environment}"}"
  retention_in_days = 14

  tags = local.tags
}

# =============================================================================
# stream_to_stepfunction Lambda (DynamoDB stream trigger)
# =============================================================================

data "aws_s3_object" "stream_to_stepfunction_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "stream_to_stepfunction${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_iam_role" "stream_to_stepfunction_role" {
  name = "tops-stream-to-sfn-role${var.environment == "prod" ? "" : "-${var.environment}"}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_policy" "stream_to_stepfunction_policy" {
  name        = "tops-stream-to-sfn-policy${var.environment == "prod" ? "" : "-${var.environment}"}"
  description = "IAM Policy for stream_to_stepfunction Lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # CloudWatch Logs
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:CreateLogGroup"],
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/tops-stream-to-sfn*"
      },
      # DynamoDB Stream read access
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:DescribeStream",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams"
        ],
        Resource = aws_dynamodb_table.lab_deployment_state.stream_arn
      },
      # DynamoDB table access for lab config
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem"
        ],
        Resource = aws_dynamodb_table.lab_configuration.arn
      },
      # Step Function execution
      {
        Effect = "Allow",
        Action = [
          "states:StartExecution"
        ],
        Resource = aws_sfn_state_machine.provisioning_workflow.arn
      },
      # S3 for deployment state
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.deployment_state.arn}/*"
      },
      # DynamoDB for job state
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ],
        Resource = [
          aws_dynamodb_table.job_state.arn,
          "${aws_dynamodb_table.job_state.arn}/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "stream_to_stepfunction_attach" {
  role       = aws_iam_role.stream_to_stepfunction_role.name
  policy_arn = aws_iam_policy.stream_to_stepfunction_policy.arn
}

resource "aws_lambda_function" "stream_to_stepfunction_lambda" {
  function_name    = "tops-stream-to-sfn${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.stream_to_stepfunction_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = "stream_to_stepfunction${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
  source_code_hash = data.aws_s3_object.stream_to_stepfunction_zip.etag
  kms_key_arn      = aws_kms_key.lambda_encryption.arn

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      DEPLOYMENT_STATE_TABLE      = aws_dynamodb_table.lab_deployment_state.name
      LAB_CONFIGURATION_TABLE     = aws_dynamodb_table.lab_configuration.name
      STEP_FUNCTION_ARN           = aws_sfn_state_machine.provisioning_workflow.arn
      DEPLOYMENT_STATE_BUCKET     = aws_s3_bucket.deployment_state.bucket
      JOB_STATE_TABLE             = aws_dynamodb_table.job_state.name
    }
  }

  tags = local.tags
}

# Note: DynamoDB stream trigger is NOT added here.
# The existing udf_worker_lambda still handles the stream.
# Enable this mapping when ready to migrate from udf_worker to Step Functions:
#
# resource "aws_lambda_event_source_mapping" "stream_to_stepfunction_trigger" {
#   function_name     = aws_lambda_function.stream_to_stepfunction_lambda.arn
#   event_source_arn  = aws_dynamodb_table.lab_deployment_state.stream_arn
#   starting_position = "LATEST"
#   batch_size        = 1
#   maximum_retry_attempts = 0
#   enabled           = true
#
#   filter_criteria {
#     filter {
#       pattern = "{ \"eventName\": [\"INSERT\"] }"
#     }
#   }
# }

# =============================================================================
# Outputs
# =============================================================================

output "provisioning_workflow_arn" {
  description = "ARN of the provisioning Step Function"
  value       = aws_sfn_state_machine.provisioning_workflow.arn
}

output "provisioning_workflow_name" {
  description = "Name of the provisioning Step Function"
  value       = aws_sfn_state_machine.provisioning_workflow.name
}

output "fetch_job_config_lambda_arn" {
  description = "ARN of the fetch_job_config Lambda"
  value       = aws_lambda_function.fetch_job_config_lambda.arn
}

output "resource_orchestrator_lambda_arn" {
  description = "ARN of the resource_orchestrator Lambda"
  value       = aws_lambda_function.resource_orchestrator_lambda.arn
}

output "stream_to_stepfunction_lambda_arn" {
  description = "ARN of the stream_to_stepfunction Lambda"
  value       = aws_lambda_function.stream_to_stepfunction_lambda.arn
}

output "origin_pool_create_lambda_arn" {
  description = "ARN of the origin_pool_create Lambda"
  value       = aws_lambda_function.origin_pool_create_lambda.arn
}

output "http_lb_create_lambda_arn" {
  description = "ARN of the http_lb_create Lambda"
  value       = aws_lambda_function.http_lb_create_lambda.arn
}

output "waf_policy_create_lambda_arn" {
  description = "ARN of the waf_policy_create Lambda"
  value       = aws_lambda_function.waf_policy_create_lambda.arn
}
