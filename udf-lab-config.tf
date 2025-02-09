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
  bucket        = "tops-registry${var.environment == "prod" ? "" : "-${var.environment}"}"
  force_destroy = true

  lifecycle {
    prevent_destroy = true
  }

  tags = local.tags
}

/*
Individual Lab Configs here
*/

resource "aws_dynamodb_table_item" "lab_cMIxKy" {
  table_name = aws_dynamodb_table.lab_configuration.name
  hash_key   = "lab_id"

  item = jsonencode({
    lab_id          = { S = "cMIxKy" }
    description     = { S = "Lab for testing" }
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
    pre_lambda      = { S = "${aws_lambda_function.cMIxKy_pre_lambda.arn}" }
    post_lambda     = { NULL = true }
  })
}

resource "aws_s3_object" "lab_info_cMIxKy" {
  bucket  = aws_s3_bucket.lab_registry_bucket.bucket
  key     = "cMIxKy.yaml"
  content = <<EOT
lab_id: cMIxKy
sqsURL: "${aws_sqs_queue.udf_queue.url}"
EOT

  content_type = "text/yaml"
  etag         = md5(filebase64("${path.module}/cMIxKy.yaml"))
}