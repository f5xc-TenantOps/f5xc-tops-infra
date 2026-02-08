resource "aws_iam_role" "utility_lambda_role" {
  name = "tops-utility-role${var.environment == "prod" ? "" : "-${var.environment}"}"

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
}

resource "aws_iam_policy" "utility_lambda_policy" {
  name        = "utility-lambda-policy${var.environment == "prod" ? "" : "-${var.environment}"}"
  description = "IAM Policy for the Token Refresh Lambda Functions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:CreateLogGroup"],
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/tops-*"
      },
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ],
        Resource = "arn:aws:ssm:us-east-1:317124676658:parameter/*"
      },
      # State persistence: S3 for deployment state
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.deployment_state.arn}/*"
      },
      # State persistence: DynamoDB for job state
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.job_state.arn,
          "${aws_dynamodb_table.job_state.arn}/index/*"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "utility_lambda_attach" {
  role       = aws_iam_role.utility_lambda_role.name
  policy_arn = aws_iam_policy.utility_lambda_policy.arn
}

data "aws_s3_object" "user_create_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "user_create${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_lambda_function" "user_create_lambda" {
  function_name    = "tops-user-create${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.utility_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.handler"
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = "user_create${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
  source_code_hash = data.aws_s3_object.user_create_zip.etag
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

data "aws_s3_object" "user_remove_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "user_remove${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}


resource "aws_lambda_function" "user_remove_lambda" {
  function_name    = "tops-user-remove${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.utility_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.handler"
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = "user_remove${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
  source_code_hash = data.aws_s3_object.user_remove_zip.etag
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

data "aws_s3_object" "ns_create_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "ns_create${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_lambda_function" "ns_create_lambda" {
  function_name    = "tops-ns-create${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.utility_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.handler"
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = "ns_create${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
  source_code_hash = data.aws_s3_object.ns_create_zip.etag
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

data "aws_s3_object" "ns_remove_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "ns_remove${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_lambda_function" "ns_remove_lambda" {
  function_name    = "tops-ns-remove${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.utility_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.handler"
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = "ns_remove${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
  source_code_hash = data.aws_s3_object.ns_remove_zip.etag
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
