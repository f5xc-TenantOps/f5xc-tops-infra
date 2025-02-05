resource "aws_sqs_queue" "udf_queue" {
  name                      = "tops-udf-queue${var.environment == "prod" ? "" : "-${var.environment}"}"
  message_retention_seconds = 3600
  visibility_timeout_seconds = 60
  delay_seconds             = 0
  receive_wait_time_seconds = 10
}

resource "aws_sqs_queue_policy" "udf_queue_policy" {
  queue_url = aws_sqs_queue.udf_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowLambdaToConsumeSQS",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action    = "sqs:ReceiveMessage",
        Resource  = aws_sqs_queue.udf_queue.arn
      },
      {
        Sid       = "AllowUDFToSendSQS",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action    = "sqs:SendMessage",
        Condition = {
          "ForAnyValue:StringEquals": {
            "aws:PrincipalOrgPaths": var.udf_principal_org_path
          }
        }
        Resource  = aws_sqs_queue.udf_queue.arn
      },
      {
        Sid       = "AllowSQSManagementForAccount",
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action    = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource  = aws_sqs_queue.udf_queue.arn
      }
    ]
  })
}

data "aws_s3_object" "udf_timer_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "udf_timer${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_iam_role" "udf_timer_lambda_role" {
  name = "tops-udf-timer-role${var.environment == "prod" ? "" : "-${var.environment}"}"

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

resource "aws_iam_policy" "udf_timer_lambda_policy" {
  name        = "udf_timer_lambda_policy${var.environment == "prod" ? "" : "-${var.environment}"}"
  description = "IAM Policy for the UDF Timer Lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # ✅ Allow Lambda to log
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:CreateLogGroup"],
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/tops-udf-timer*"
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
        Action   = ["dynamodb:GetRecords", "dynamodb:PutItem", "dynamodb:UpdateItem"],
        Resource = aws_dynamodb_table.lab_deployment_state.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "udf_timer_lambda_attach" {
  role       = aws_iam_role.udf_timer_lambda_role.name
  policy_arn = aws_iam_policy.udf_timer_lambda_policy.arn
}

resource "aws_lambda_function" "udf_timer_lambda" {
  function_name    = "tops-udf-timer${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.udf_timer_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = data.aws_s3_object.udf_timer_zip.bucket
  s3_key           = data.aws_s3_object.udf_timer_zip.key
  source_code_hash = data.aws_s3_object.udf_timer_zip.etag

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      DEPLOYMENT_STATE_TABLE    = aws_dynamodb_table.lab_deployment_state.name
      UDF_QUEUE                 = aws_sqs_queue.udf_queue.name
    }
  }

  tags = local.tags
}

resource "aws_lambda_event_source_mapping" "udf_timer_sqs_trigger" {
  function_name    = aws_lambda_function.udf_timer_lambda.arn
  event_source_arn = aws_sqs_queue.udf_queue.arn
  batch_size       = 1  # Ensure processing of one message at a time
  enabled          = true
}