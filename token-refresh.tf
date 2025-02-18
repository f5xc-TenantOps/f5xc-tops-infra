/*
Lambda function to refresh tenant access tokens
*/
data "aws_s3_object" "token_refresh_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "token_refresh${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_iam_role" "token_refresh_lambda_role" {
  name = "tops-token-refresh-role${var.environment == "prod" ? "" : "-${var.environment}"}"

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

resource "aws_iam_policy" "token_refresh_lambda_policy" {
  name        = "token-refresh-lambda-policy${var.environment == "prod" ? "" : "-${var.environment}"}"
  description = "IAM Policy for the Token Refresh Lambda Functions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:CreateLogGroup"],
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/tops-token-refresh*"
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
    ]
  })
}

resource "aws_iam_role_policy_attachment" "token_refresh_lambda_attach" {
  role       = aws_iam_role.token_refresh_lambda_role.name
  policy_arn = aws_iam_policy.token_refresh_lambda_policy.arn
}

/*
MCN Token Refresh Lambda
*/
resource "aws_lambda_function" "token_refresh_mcn_lambda" {
  function_name    = "tops-token-refresh-mcn${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.token_refresh_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = data.aws_s3_object.token_refresh_zip.bucket
  s3_key           = data.aws_s3_object.token_refresh_zip.key
  source_code_hash = data.aws_s3_object.token_refresh_zip.etag

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      "SSM_BASE_PATH" = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/mcn-lab"
    }
  }

  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "token_refresh_mcn_schedule" {
  name                = "tops-token-refresh-mcn-schedule${var.environment == "prod" ? "" : "-${var.environment}"}"
  description         = "Scheduled trigger for token refresh Lambda"
  schedule_expression = "rate(12 hours)"
}

resource "aws_cloudwatch_event_target" "token_refresh_mcn_lambda_target" {
  rule      = aws_cloudwatch_event_rule.token_refresh_mcn_schedule.name
  target_id = "lambda-target-mcn"
  arn       = aws_lambda_function.token_refresh_mcn_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_token_refresh_mcn" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.token_refresh_mcn_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.token_refresh_mcn_schedule.arn
}

/*
Security Tenant Token Refresh Lambda
*/
resource "aws_lambda_function" "token_refresh_sec_lambda" {
  function_name    = "tops-token-refresh-sec${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.token_refresh_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = data.aws_s3_object.token_refresh_zip.bucket
  s3_key           = data.aws_s3_object.token_refresh_zip.key
  source_code_hash = data.aws_s3_object.token_refresh_zip.etag

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      "SSM_BASE_PATH" = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/sec-lab"
    }
  }

  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "token_refresh_sec_schedule" {
  name                = "tops-token-refresh-sec-schedule${var.environment == "prod" ? "" : "-${var.environment}"}"
  description         = "Scheduled trigger for token refresh Lambda"
  schedule_expression = "rate(12 hours)"
}

resource "aws_cloudwatch_event_target" "token_refresh_sec_lambda_target" {
  rule      = aws_cloudwatch_event_rule.token_refresh_sec_schedule.name
  target_id = "lambda-target-sec"
  arn       = aws_lambda_function.token_refresh_sec_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_token_refresh_sec" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.token_refresh_sec_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.token_refresh_sec_schedule.arn
}

/*
App Tenant Token Refresh Lambda
*/

resource "aws_lambda_function" "token_refresh_app_lambda" {
  function_name    = "tops-token-refresh-app${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.token_refresh_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = data.aws_s3_object.token_refresh_zip.bucket
  s3_key           = data.aws_s3_object.token_refresh_zip.key
  source_code_hash = data.aws_s3_object.token_refresh_zip.etag

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      "SSM_BASE_PATH" = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/sec-lab"
    }
  }

  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "token_refresh_app_schedule" {
  name                = "tops-token-refresh-app-schedule${var.environment == "prod" ? "" : "-${var.environment}"}"
  description         = "Scheduled trigger for token refresh Lambda"
  schedule_expression = "rate(12 hours)"
}

resource "aws_cloudwatch_event_target" "token_refresh_app_lambda_target" {
  rule      = aws_cloudwatch_event_rule.token_refresh_app_schedule.name
  target_id = "lambda-target-app"
  arn       = aws_lambda_function.token_refresh_app_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_token_refresh_app" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.token_refresh_app_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.token_refresh_app_schedule.arn
}