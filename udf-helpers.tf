/*
Lambda functions to help UDF labs
*/
resource "aws_iam_role" "udf_helpers_lambda_role" {
  name = "tops-udf-helpers-role${var.environment == "prod" ? "" : "-${var.environment}"}"

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

resource "aws_iam_policy" "udf_helpers_lambda_policy" {
  name        = "udf-helpers-lambda-policy${var.environment == "prod" ? "" : "-${var.environment}"}"
  description = "IAM Policy for the Token Refresh Lambda Functions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"],
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

resource "aws_iam_role_policy_attachment" "udf_helpers_lambda_attach" {
  role       = aws_iam_role.udf_helpers_lambda_role.name
  policy_arn = aws_iam_policy.udf_helpers_lambda_policy.arn
}

/*
Function Resources
*/

data "aws_s3_object" "cMIxKy_pre_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "cMIxKy-pre${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_lambda_function" "cMIxKy_pre_lambda" {
  function_name    = "tops-helper-cMIxKy-pre${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.token_refresh_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = data.aws_s3_object.cMIxKy_pre_zip.bucket
  s3_key           = data.aws_s3_object.cMIxKy_pre_zip.key
  source_code_hash = data.aws_s3_object.cMIxKy_pre_zip.etag

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  tags = local.tags
}