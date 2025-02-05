/*
UDF Worker Lambda
*/
resource "aws_dynamodb_table" "lab_deployment_state" {
  name         = "tops-lab-deployment-state${var.environment == "prod" ? "" : "-${var.environment}"}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "deployment_id"

  attribute {
    name = "deployment_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
}

data "aws_s3_object" "udf_worker_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "udf_worker${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_iam_role" "udf_worker_lambda_role" {
  name = "tops-udf-worker-role${var.environment == "prod" ? "" : "-${var.environment}"}"

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

resource "aws_iam_policy" "udf_worker_lambda_policy" {
  name        = "udf_worker_lambda_policy${var.environment == "prod" ? "" : "-${var.environment}"}"
  description = "IAM Policy for the UDF Worker Lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # ✅ Allow Lambda to log
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:CreateLogGroup"],
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/tops-udf-worker*"
      },

      # ✅ Allow Lambda to read from the **DynamoDB Stream** (use stream ARN)
      {
        Effect   = "Allow",
        Action   = [
          "dynamodb:GetRecords",
          "dynamodb:DescribeStream",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams"
        ],
        Resource = aws_dynamodb_table.lab_deployment_state.stream_arn
      },

      # ✅ Allow Lambda to interact with **DynamoDB Table** (use table ARN)
      {
        Effect   = "Allow",
        Action   = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ],
        Resource = aws_dynamodb_table.lab_deployment_state.arn
      },

      {
        Effect   = "Allow",
        Action   = [
          "dynamodb:GetItem"
        ],
        Resource = aws_dynamodb_table.lab_configuration.arn
      },

      # ✅ Allow Lambda to invoke other Lambda functions
      {
        Effect   = "Allow",
        Action   = ["lambda:InvokeFunction"],
        Resource = [
          "arn:aws:lambda:*:*:function:tops-user*",
          "arn:aws:lambda:*:*:function:tops-ns*",
          "arn:aws:lambda:*:*:function:tops-helper*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "udf_worker_lambda_attach" {
  role       = aws_iam_role.udf_worker_lambda_role.name
  policy_arn = aws_iam_policy.udf_worker_lambda_policy.arn
}

resource "aws_lambda_function" "udf_worker_lambda" {
  function_name    = "tops-udf-worker${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.udf_worker_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = data.aws_s3_object.udf_worker_zip.bucket
  s3_key           = data.aws_s3_object.udf_worker_zip.key
  source_code_hash = data.aws_s3_object.udf_worker_zip.etag

  environment {
    variables = {
      DEPLOYMENT_STATE_TABLE      = aws_dynamodb_table.lab_deployment_state.name
      LAB_CONFIGURATION_TABLE     = aws_dynamodb_table.lab_configuration.name
      USER_CREATE_LAMBDA_FUNCTION = aws_lambda_function.user_create_lambda.arn
      USER_REMOVE_LAMBDA_FUNCTION = aws_lambda_function.user_remove_lambda.arn
      NS_CREATE_LAMBDA_FUNCTION   = aws_lambda_function.ns_create_lambda.arn
      NS_REMOVE_LAMBDA_FUNCTION   = aws_lambda_function.ns_remove_lambda.arn
    }
  }

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  tags = local.tags
}

resource "aws_lambda_event_source_mapping" "udf_worker_dynamodb_trigger" {
  function_name     = aws_lambda_function.udf_worker_lambda.arn
  event_source_arn  = aws_dynamodb_table.lab_deployment_state.stream_arn
  starting_position = "LATEST"
  batch_size        = 1
  enabled           = true

  filter_criteria {
    filter {
      pattern = "{ \"eventName\": [\"INSERT\", \"REMOVE\"] }"
    }
  }
}
