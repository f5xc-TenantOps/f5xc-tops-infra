/*
Customer-managed KMS key for Lambda environment variable encryption.

Using a customer-managed key avoids stale KMS grant issues that occur
with the AWS-managed aws/lambda key when IAM roles are recreated by
Crossplane (grants are tied to the old role unique ID).
*/

resource "aws_kms_key" "lambda_encryption" {
  description             = "KMS key for Lambda environment variable encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowAccountRootFullAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "AllowLambdaServiceAccess",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

resource "aws_kms_alias" "lambda_encryption" {
  name          = "alias/tops-lambda-key${var.environment == "prod" ? "" : "-${var.environment}"}"
  target_key_id = aws_kms_key.lambda_encryption.key_id
}
