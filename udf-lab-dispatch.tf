resource "aws_sqs_queue" "udf_queue" {
  name                      = "tops-udf-queue${var.environment == "prod" ? "" : "-${var.environment}"}"
  message_retention_seconds = 60
  visibility_timeout_seconds = 61
  delay_seconds             = 0
  receive_wait_time_seconds = 10

}

resource "aws_sqs_queue" "udf_dlq" {
  name = "tops-udf-dlq${var.environment == "prod" ? "" : "-${var.environment}"}"
  message_retention_seconds = 259200
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
          AWS = "*"
        },
        Action    = "sqs:SendMessage",
        Condition = {
          "ForAnyValue:StringLike": {
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

data "aws_s3_object" "udf_dispatch_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "udf_dispatch${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_iam_role" "udf_dispatch_lambda_role" {
  name = "tops-udf-dispatch-role${var.environment == "prod" ? "" : "-${var.environment}"}"

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

resource "aws_iam_policy" "udf_dispatch_lambda_policy" {
  name        = "udf_dispatch_lambda_policy${var.environment == "prod" ? "" : "-${var.environment}"}"
  description = "IAM Policy for the UDF dispatch Lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # ✅ Allow Lambda to log
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:CreateLogGroup"],
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/tops-udf-dispatch*:*"
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
          "dynamodb:UpdateItem"
        ],
        Resource = aws_dynamodb_table.lab_deployment_state.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "udf_dispatch_lambda_attach" {
  role       = aws_iam_role.udf_dispatch_lambda_role.name
  policy_arn = aws_iam_policy.udf_dispatch_lambda_policy.arn
}

resource "aws_lambda_function" "udf_dispatch_lambda" {
  function_name    = "tops-udf-dispatch${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.udf_dispatch_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = data.aws_s3_object.udf_dispatch_zip.bucket
  s3_key           = data.aws_s3_object.udf_dispatch_zip.key
  source_code_hash = data.aws_s3_object.udf_dispatch_zip.etag
  kms_key_arn      = aws_kms_key.lambda_encryption.arn

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

resource "aws_lambda_event_source_mapping" "udf_dispatch_sqs_trigger" {
  function_name    = aws_lambda_function.udf_dispatch_lambda.arn
  event_source_arn = aws_sqs_queue.udf_queue.arn
  batch_size       = 1  # Ensure processing of one message at a time
  enabled          = true
}