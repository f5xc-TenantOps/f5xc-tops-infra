
data "aws_s3_object" "udf_cleaner_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "udf_clean${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_iam_role" "udf_cleaner_lambda_role" {
  name = "tops-udf-cleaner-role${var.environment == "prod" ? "" : "-${var.environment}"}"

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

resource "aws_iam_policy" "udf_cleaner_lambda_policy" {
  name        = "udf_cleaner_lambda_policy${var.environment == "prod" ? "" : "-${var.environment}"}"
  description = "IAM Policy for the UDF cleaner Lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # ✅ Allow Lambda to log
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:CreateLogGroup"],
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/tops-udf-cleaner*:*"
      },

      # ✅ Allow Lambda to receive and delete messages from SQS
      {
        Effect   = "Allow",
        Action   = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ],
        Resource = aws_sqs_queue.udf_queue.arn
      },

      # ✅ Allow Lambda to interact with DynamoDB
      {
        Effect   = "Allow",
        Action   = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ],
        Resource = aws_dynamodb_table.lab_deployment_state.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "udf_cleaner_lambda_attach" {
  role       = aws_iam_role.udf_cleaner_lambda_role.name
  policy_arn = aws_iam_policy.udf_cleaner_lambda_policy.arn
}

resource "aws_lambda_function" "udf_lab_cleaner_lambda" {
  function_name    = "tops-udf-cleaner${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.udf_cleaner_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = data.aws_s3_object.udf_cleaner_zip.bucket
  s3_key           = data.aws_s3_object.udf_cleaner_zip.key
  source_code_hash = data.aws_s3_object.udf_cleaner_zip.etag

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      DEPLOYMENT_STATE_TABLE    = aws_dynamodb_table.lab_deployment_state.name
    }
  }

  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "udf_lab_cleaner_schedule" {
  name                = "tops-udf-lab-cleaner-schedule${var.environment == "prod" ? "" : "-${var.environment}"}"
  description         = "Scheduled trigger for UDF Cleaner Lambda"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "udf_lab_cleaner_lambda_target" {
  rule      = aws_cloudwatch_event_rule.udf_lab_cleaner_schedule.name
  target_id = "lambda-target-app"
  arn       = aws_lambda_function.udf_lab_cleaner_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_udf_lab_cleaner" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.udf_lab_cleaner_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.udf_lab_cleaner_schedule.arn
}