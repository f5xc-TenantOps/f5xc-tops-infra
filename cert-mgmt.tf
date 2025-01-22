module "cert_bucket" {
  source      = "./modules/bucket"
  bucket_name = "tops-cert-bucket${var.environment == "prod" ? "" : "-${var.environment}"}"

  tags = local.tags
}

module "cert_mgmt_ecr" {
  source          = "./modules/ecr"
  repository_name = "tops-cert-mgmt${var.environment == "prod" ? "" : "-${var.environment}"}"
  tags = local.tags
}

module "cert_mgmt_mcn_lambda" {
  source                = "./modules/lambda"
  function_name         = "tops-cert-mgmt-mcn${var.environment == "prod" ? "" : "-${var.environment}"}"
  lambda_role_arn       = aws_iam_role.lambda_execution_role.arn
  ecr_repository_url    = module.cert_mgmt_ecr.repository_url
  environment_variables = {
    "SSM_BASE_PATH" = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/mcn-lab",
    "S3_BUCKET"     = module.cert_bucket.cert_bucket_name,
  }
  trigger_type          = "schedule"
  schedule_expression   = "rate(1 day)"
  tags                  = local.tags
}

module "acme_client_ecr" {
  source          = "./modules/ecr"
  repository_name = "tops-acme-client${var.environment == "prod" ? "" : "-${var.environment}"}"
  tags = local.tags
}

module "acme_client_mcn_lambda" {
  source                = "./modules/lambda"
  function_name         = "tops-acme-client-mcn${var.environment == "prod" ? "" : "-${var.environment}"}"
  lambda_role_arn       = aws_iam_role.lambda_execution_role.arn
  ecr_repository_url    = module.acme_client_ecr.repository_url
  environment_variables = {
    "CERT_NAME"     = "mcn-lab-wildcard${var.environment == "prod" ? "" : "-${var.environment}"}",
    "DOMAIN"        = "*.mcn-lab.f5demos.com",
    "S3_BUCKET"     = module.cert_bucket.cert_bucket_name,
    "EMAIL"         = var.acme_email
  }
  trigger_type          = "schedule"
  schedule_expression   = "rate(1 day)"
  tags                  = local.tags
}

output "cert_bucket_name" {
  value = module.cert_bucket.cert_bucket_name
}

output "cert_bucket_arn" {
  value = module.cert_bucket.cert_bucket_arn
}

output "cert_ecr_url" {
  description = "The URL of the ECR repository"
  value       = module.cert_ecr.repository_url
}

output "cert_ecr_arn" {
  description = "The ARN of the ECR repository"
  value       = module.cert_ecr.repository_arn
}