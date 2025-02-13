resource "aws_dynamodb_table" "lab_configuration" {
  name         = "tops-lab-config${var.environment == "prod" ? "" : "-${var.environment}"}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "lab_id"

  attribute {
    name = "lab_id"
    type = "S"
  }
}

resource "aws_s3_bucket" "lab_registry_bucket" {
  bucket        = "tops-registry-bucket${var.environment == "prod" ? "" : "-${var.environment}"}"
  force_destroy = true

  lifecycle {
    prevent_destroy = true
  }

  tags = local.tags
}

resource "aws_s3_bucket_policy" "lab_registry_policy" {
  bucket = aws_s3_bucket.lab_registry_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowCrossAccountRead",
        Effect    = "Allow",
        Principal = "*", 
        Condition = {
          "ForAnyValue:StringLike": {
            "aws:PrincipalOrgPaths": var.udf_principal_org_path
          }
        },
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.lab_registry_bucket.bucket}"
        ]
      },
     {
        Sid       = "ReadFiles",
        Effect    = "Allow",
        Principal = "*", 
        Condition = {
          "ForAnyValue:StringLike": {
            "aws:PrincipalOrgPaths": var.udf_principal_org_path
          }
        },
        Action = [
          "s3:GetObject"
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.lab_registry_bucket.bucket}/*"
        ]
      }
    ]
  })
}

/*
Individual Lab Configs here
*/

########################################
# Example Lab                          #
########################################
resource "aws_dynamodb_table_item" "lab_e37500bc" {
  table_name = aws_dynamodb_table.lab_configuration.name
  hash_key   = "lab_id"

  item = jsonencode({
    lab_id          = { S = "e37500bc" }
    description     = { S = "Example lab for testing" }
    ssm_base_path   = { S = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/mcn-lab" }
    group_names     = { L = [
      { S = "xc-lab-users" }
    ]}
    namespace_roles = { L = [
      { M = {
        namespace = { S = "system" }
        role      = { S = "f5xc-web-app-scanning-user" }
      }}
    ]}
    user_ns         = { BOOL = true }
    pre_lambda      = { S = "${aws_lambda_function.example_pre_lambda.arn}" }
    post_lambda     = { NULL = true }
  })
}

resource "aws_s3_object" "lab_info_e37500bc" {
  bucket  = aws_s3_bucket.lab_registry_bucket.bucket
  key     = "e37500bc.yaml"
  content = <<EOT
lab_id: e37500bc
sqsURL: "${aws_sqs_queue.udf_queue.url}"
EOT

  content_type = "text/yaml"
}

########################################
# API Lab                              #
########################################
resource "aws_dynamodb_table_item" "lab_648ecc3e" {
  table_name = aws_dynamodb_table.lab_configuration.name
  hash_key   = "lab_id"

  item = jsonencode({
    lab_id          = { S = "648ecc3e" }
    description     = { S = "API Lab" }
    ssm_base_path   = { S = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/sec-lab" }
    group_names     = { L = [
      { S = "xc-lab-users" }
    ]}
    namespace_roles = { L = [
      { M = {
        namespace = { S = "system" }
        role      = { S = "f5xc-web-app-scanning-user" }
      }}
    ]}
    user_ns         = { BOOL = true }
    pre_lambda      = { S = "${aws_lambda_function.apilab_pre_lambda.arn}" }
    post_lambda     = { NULL = true }
  })
}

resource "aws_s3_object" "lab_info_648ecc3e" {
  bucket  = aws_s3_bucket.lab_registry_bucket.bucket
  key     = "648ecc3e.yaml"
  content = <<EOT
lab_id: 648ecc3e
sqsURL: "${aws_sqs_queue.udf_queue.url}"
EOT

  content_type = "text/yaml"
}

########################################
# Bot Lab                              #
########################################
resource "aws_dynamodb_table_item" "lab_f85bfeb4" {
  table_name = aws_dynamodb_table.lab_configuration.name
  hash_key   = "lab_id"

  item = jsonencode({
    lab_id          = { S = "f85bfeb4" }
    description     = { S = "Bot Lab" }
    ssm_base_path   = { S = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/sec-lab" }
    group_names     = { L = [
      { S = "xc-lab-users" }
    ]}
    namespace_roles = { L = [
      { M = {
        namespace = { S = "system" }
        role      = { S = "f5xc-web-app-scanning-user" }
      }}
    ]}
    user_ns         = { BOOL = true }
    pre_lambda      = { S = "${aws_lambda_function.botlab_pre_lambda.arn}" }
    post_lambda     = { NULL = true }
  })
}

resource "aws_s3_object" "lab_info_f85bfeb4" {
  bucket  = aws_s3_bucket.lab_registry_bucket.bucket
  key     = "f85bfeb4.yaml"
  content = <<EOT
lab_id: f85bfeb4
sqsURL: "${aws_sqs_queue.udf_queue.url}"
EOT

  content_type = "text/yaml"
}

########################################
# CAAS Lab                             #
########################################
resource "aws_dynamodb_table_item" "lab_811c573b" {
  table_name = aws_dynamodb_table.lab_configuration.name
  hash_key   = "lab_id"

  item = jsonencode({
    lab_id          = { S = "811c573b" }
    description     = { S = "CAAS Lab" }
    ssm_base_path   = { S = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/app-lab" }
    group_names     = { L = [
      { S = "xc-lab-users" }
    ]}
    namespace_roles = { L = [
      { M = {
        namespace = { S = "system" }
        role      = { S = "f5xc-web-app-scanning-user" }
      }}
    ]}
    user_ns         = { BOOL = true }
    pre_lambda      = { S = "${aws_lambda_function.caaslab_pre_lambda.arn}" }
    post_lambda     = { NULL = true }
  })
}

resource "aws_s3_object" "lab_info_811c573b" {
  bucket  = aws_s3_bucket.lab_registry_bucket.bucket
  key     = "811c573b.yaml"
  content = <<EOT
lab_id: 811c573b
sqsURL: "${aws_sqs_queue.udf_queue.url}"
EOT

  content_type = "text/yaml"
}

########################################
# WAAP Lab                             #
########################################
resource "aws_dynamodb_table_item" "lab_d3c24766" {
  table_name = aws_dynamodb_table.lab_configuration.name
  hash_key   = "lab_id"

  item = jsonencode({
    lab_id          = { S = "d3c24766" }
    description     = { S = "WAAP Lab" }
    ssm_base_path   = { S = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/sec-lab" }
    group_names     = { L = [
      { S = "xc-lab-users" }
    ]}
    namespace_roles = { L = [
      { M = {
        namespace = { S = "system" }
        role      = { S = "f5xc-web-app-scanning-user" }
      }}
    ]}
    user_ns         = { BOOL = true }
    pre_lambda      = { S = "${aws_lambda_function.caaslab_pre_lambda.arn}" }
    post_lambda     = { NULL = true }
  })
}

resource "aws_s3_object" "lab_info_d3c24766" {
  bucket  = aws_s3_bucket.lab_registry_bucket.bucket
  key     = "811c573b.yaml"
  content = <<EOT
lab_id: 811c573b
sqsURL: "${aws_sqs_queue.udf_queue.url}"
EOT

  content_type = "text/yaml"
}