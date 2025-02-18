variable "mcn_lab_token" {
  description = "Access token for the MCN Lab Tenant"
  type        = string
  sensitive   = true
}

variable "app_lab_token" {
  description = "Access token for the App Lab Tenant"
  type        = string
  sensitive   = true
}

variable "sec_lab_token" {
  description = "Access token for the Sec Lab Tenant"
  type        = string
  sensitive   = true
}

locals {
  app_base_path = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/app-lab"
  mcn_base_path = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/mcn-lab"
  sec_base_path = "/tenantOps${var.environment == "prod" ? "" : "-${var.environment}"}/sec-lab"
}

module "app_lab_parameters" {
  source = "./modules/parameter-store"

  parameters = {
    "${local.app_base_path}/tenant-url" = {
      type        = "String"
      value       = "https://f5-xc-lab-app.console.ves.volterra.io"
    }
    "${local.app_base_path}/idm-type" = {
      type        = "String"
      value       = "SSO"
    }
    "${local.app_base_path}/token-name" = {
      type        = "String"
      value       = "tenant-operations-ldfbcohs"
    }
    "${local.app_base_path}/token-type" = {
      type        = "String"
      value       = "svccred"
    }
    "${local.app_base_path}/token-value" = {
      type        = "SecureString"
      value       = var.app_lab_token
    }
  }
  default_tags    = local.tags
}

module "mcn_lab_parameters" {
  source = "./modules/parameter-store"

  parameters = {
    "${local.mcn_base_path}/tenant-url" = {
      type        = "String"
      value       = "https://f5-xc-lab-mcn.console.ves.volterra.io"
    }
    "${local.mcn_base_path}/idm-type" = {
      type        = "String"
      value       = "SSO"
    }
    "${local.mcn_base_path}/token-name" = {
      type        = "String"
      value       = "tenant-operations-kubdrbpy"
    }
    "${local.mcn_base_path}/token-type" = {
      type        = "String"
      value       = "svccred"
    }
    "${local.mcn_base_path}/token-value" = {
      type        = "SecureString"
      value       = var.mcn_lab_token
    }
  }
  default_tags    = local.tags
}

module "sec_lab_parameters" {
  source = "./modules/parameter-store"

  parameters = {
    "${local.sec_base_path}/tenant-url" = {
      type        = "String"
      value       = "https://f5-xc-lab-sec.console.ves.volterra.io"
    }
    "${local.sec_base_path}/idm-type" = {
      type        = "String"
      value       = "SSO"
    }
    "${local.sec_base_path}/token-name" = {
      type        = "String"
      value       = "tenant-operations-eawmoood"
    }
    "${local.sec_base_path}/token-type" = {
      type        = "String"
      value       = "svccred"
    }
    "${local.sec_base_path}/token-value" = {
      type        = "SecureString"
      value       = var.sec_lab_token
    }
  }
  default_tags    = local.tags
}