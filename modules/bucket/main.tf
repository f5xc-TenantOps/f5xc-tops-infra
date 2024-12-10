/* Variables */

variable "aws_region" {
  description = "AWS region for the S3 bucket"
  type        = string
  default     = ""
}

variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to the S3 bucket"
  type        = map(string)
  default     = {}
}

/* Resources */
resource "aws_s3_bucket" "this_bucket" {
  bucket        = var.bucket_name
  force_destroy = true

  lifecycle {
    prevent_destroy = true
  }

  tags = var.tags
}

/* Outputs */
output "cert_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.this_bucket.bucket
}

output "cert_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.this_bucket.arn
}