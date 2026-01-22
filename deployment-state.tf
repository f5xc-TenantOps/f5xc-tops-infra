# deployment-state.tf
# S3 bucket for deployment state files polled by UDF lab service

resource "aws_s3_bucket" "deployment_state" {
  bucket = "tops-deployment-state${var.environment == "prod" ? "" : "-${var.environment}"}"

  tags = local.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "deployment_state_lifecycle" {
  bucket = aws_s3_bucket.deployment_state.id

  rule {
    id     = "expire-old-deployments"
    status = "Enabled"

    filter {}

    expiration {
      days = 1
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "deployment_state_encryption" {
  bucket = aws_s3_bucket.deployment_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "deployment_state_public_access" {
  bucket = aws_s3_bucket.deployment_state.id

  block_public_acls       = true
  block_public_policy     = false  # Allow cross-account policy
  ignore_public_acls      = true
  restrict_public_buckets = false  # Allow cross-account access
}

resource "aws_s3_bucket_policy" "deployment_state_policy" {
  bucket     = aws_s3_bucket.deployment_state.id
  depends_on = [aws_s3_bucket_public_access_block.deployment_state_public_access]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowUDFRead"
        Effect    = "Allow"
        Principal = "*"
        Condition = {
          "ForAnyValue:StringLike" = {
            "aws:PrincipalOrgPaths" = var.udf_principal_org_path
          }
        }
        Action   = ["s3:GetObject"]
        Resource = ["arn:aws:s3:::${aws_s3_bucket.deployment_state.bucket}/*"]
      }
    ]
  })
}

output "deployment_state_bucket_name" {
  description = "Name of the deployment state S3 bucket"
  value       = aws_s3_bucket.deployment_state.bucket
}

output "deployment_state_bucket_arn" {
  description = "ARN of the deployment state S3 bucket"
  value       = aws_s3_bucket.deployment_state.arn
}
