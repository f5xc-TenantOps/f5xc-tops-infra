/*
S3 Bucket to store all generated certificates
*/

resource "aws_s3_bucket" "cert_bucket" {
  bucket        = "tops-cert-bucket${var.environment == "prod" ? "" : "-${var.environment}"}"
  force_destroy = true

  lifecycle {
    prevent_destroy = true
  }

  tags = local.tags
}

resource "aws_s3_bucket_policy" "cert_bucket_policy" {
  bucket = aws_s3_bucket.cert_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # ✅ Allow Cert Management Lambda to Read Objects
      {
        Effect = "Allow",
        Principal = {
          "AWS" : "${aws_iam_role.cert_mgmt_lambda_role.arn}"
        },
        Action = [
          "s3:GetObject",
          "s3:ListBucket" 
        ],
        Resource = [
          "${aws_s3_bucket.cert_bucket.arn}/*",
          "${aws_s3_bucket.cert_bucket.arn}"
        ]
      },

      # ✅ Allow ACME Client Lambda to Read & Write Objects
      {
        Effect = "Allow",
        Principal = {
          "AWS" : "${aws_iam_role.acme_client_lambda_role.arn}"
        },
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "${aws_s3_bucket.cert_bucket.arn}/*",
          "${aws_s3_bucket.cert_bucket.arn}"
        ]
      }
    ]
  })
}

output "cert_bucket_name" {
  value = aws_s3_bucket.cert_bucket.bucket
}

output "cert_bucket_arn" {
  value = aws_s3_bucket.cert_bucket.arn
}

/*
Lambda function to manage certificates in tenants
*/

data "aws_s3_object" "cert_mgmt_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "cert_mgmt${var.environment == "prod" ? "" : "_${var.environment}"}.zip"
}

resource "aws_iam_role" "cert_mgmt_lambda_role" {
  name = "tops-cert-mgmt-role${var.environment == "prod" ? "" : "-${var.environment}"}"

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

resource "aws_iam_policy" "cert_mgmt_lambda_policy" {
  name        = "cert_mgmt_lambda_policy${var.environment == "prod" ? "" : "-${var.environment}"}"
  description = "IAM Policy for the Cert Management Lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:CreateLogGroup"],
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/tops-cert-mgmt*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:HeadObject"
        ],
        Resource = "${aws_s3_bucket.cert_bucket.arn}/*"
      },
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ],
        Resource = "arn:aws:ssm:us-east-1:317124676658:parameter/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cert_mgmt_lambda_attach" {
  role       = aws_iam_role.cert_mgmt_lambda_role.name
  policy_arn = aws_iam_policy.cert_mgmt_lambda_policy.arn
}

resource "aws_s3_bucket_notification" "cert_upload_triggers" {
  bucket = aws_s3_bucket.cert_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.cert_mgmt_mcn_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "lab-mcn-wildcard${var.environment == "prod" ? "" : "-${var.environment}"}/"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.cert_mgmt_app_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "lab-app-wildcard${var.environment == "prod" ? "" : "-${var.environment}"}/"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.cert_mgmt_sec_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "lab-sec-wildcard${var.environment == "prod" ? "" : "-${var.environment}"}/"
  }
}

/*Cert MGMT MCN Instance*/
resource "aws_lambda_function" "cert_mgmt_mcn_lambda" {
  function_name    = "tops-cert-mgmt-mcn${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.cert_mgmt_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = data.aws_s3_object.cert_mgmt_zip.bucket
  s3_key           = data.aws_s3_object.cert_mgmt_zip.key
  source_code_hash = data.aws_s3_object.cert_mgmt_zip.etag

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      "SSM_BASE_PATH" = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/mcn-lab"
      "S3_BUCKET"     = aws_s3_bucket.cert_bucket.bucket
      "CERT_NAME"     = "lab-mcn-wildcard${var.environment == "prod" ? "" : "-${var.environment}"}"
    }
  }

  tags = local.tags
}

resource "aws_lambda_permission" "mcn_allow_s3_to_invoke_cert_mgmt" {
  statement_id  = "MCN-AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cert_mgmt_mcn_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.cert_bucket.arn
}

/*Cert MGMT App Instance*/
resource "aws_lambda_function" "cert_mgmt_app_lambda" {
  function_name    = "tops-cert-mgmt-app${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.cert_mgmt_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = data.aws_s3_object.cert_mgmt_zip.bucket
  s3_key           = data.aws_s3_object.cert_mgmt_zip.key
  source_code_hash = data.aws_s3_object.cert_mgmt_zip.etag

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      "SSM_BASE_PATH" = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/app-lab"
      "S3_BUCKET"     = aws_s3_bucket.cert_bucket.bucket
      "CERT_NAME"     = "lab-app-wildcard${var.environment == "prod" ? "" : "-${var.environment}"}"
    }
  }

  tags = local.tags
}

resource "aws_lambda_permission" "app_allow_s3_to_invoke_cert_mgmt" {
  statement_id  = "App-AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cert_mgmt_app_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.cert_bucket.arn
}

/*Cert MGMT Sec Instance*/
resource "aws_lambda_function" "cert_mgmt_sec_lambda" {
  function_name    = "tops-cert-mgmt-sec${var.environment == "prod" ? "" : "-${var.environment}"}"
  role             = aws_iam_role.cert_mgmt_lambda_role.arn
  runtime          = "python3.11"
  handler          = "function.lambda_handler"
  s3_bucket        = data.aws_s3_object.cert_mgmt_zip.bucket
  s3_key           = data.aws_s3_object.cert_mgmt_zip.key
  source_code_hash = data.aws_s3_object.cert_mgmt_zip.etag

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      "SSM_BASE_PATH" = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/sec-lab"
      "S3_BUCKET"     = aws_s3_bucket.cert_bucket.bucket
      "CERT_NAME"     = "lab-sec-wildcard${var.environment == "prod" ? "" : "-${var.environment}"}"
    }
  }

  tags = local.tags
}

resource "aws_lambda_permission" "sec_allow_s3_to_invoke_cert_mgmt" {
  statement_id  = "SEC-AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cert_mgmt_sec_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.cert_bucket.arn
}
