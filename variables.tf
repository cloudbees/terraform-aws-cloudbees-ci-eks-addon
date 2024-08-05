# Copyright (c) CloudBees, Inc.

variable "helm_config" {
  description = "CloudBees CI Helm chart configuration."
  type        = any
  default = {
    values = [
      <<-EOT
      EOT
    ]
  }
}

variable "hosted_zone" {
  description = "Amazon Route 53 hosted zone name."
  type        = string
  validation {
    condition     = length(trimspace(var.hosted_zone)) > 0
    error_message = "Host name must not be an empty string."
  }
  validation {
    condition     = can(regex("^([a-zA-Z0-9-]+\\.)+[a-zA-Z]+$", var.hosted_zone))
    error_message = "Host name must be a valid domain name."
  }
}

variable "cert_arn" {
  description = "AWS Certificate Manager (ACM) certificate for Amazon Resource Names (ARN)."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:acm:", var.cert_arn))
    error_message = "The cert_arn should be a valid ACM certificate ARN."
  }
  validation {
    condition     = length(var.cert_arn) > 0
    error_message = "The cert_arn must not be an empty string."
  }
}

variable "trial_license" {
  description = "CloudBees CI trial license details for evaluation."
  type        = map(string)
  validation {
    condition     = contains(keys(var.trial_license), "first_name") && contains(keys(var.trial_license), "last_name") && contains(keys(var.trial_license), "email") && contains(keys(var.trial_license), "company")
    error_message = "The trial_license must contain the following keys: first_name, last_name, email, company."
  }
  validation {
    condition     = length(var.trial_license) == 4
    error_message = "The map must contain 4 keys."
  }
}

variable "create_casc_secrets" {
  description = "Create a Kubernetes basic secret for CloudBees Configuration as Code (cbci-sec-casc) and mount it into the Operation Center /var/run/secrets/cbci."
  default     = false
  type        = bool
}

variable "casc_secrets_file" {
  description = "Secrets .yml file path containing the names: values secrets. It is required when create_casc_secrets is enabled."
  default     = "secrets-values.yml"
  type        = string
  validation {
    condition     = length(trimspace(var.casc_secrets_file)) > 0
    error_message = "CasC secret file must not be an empty string."
  }
}

variable "create_reg_secret" {
  description = "Create a Kubernetes dockerconfigjson secret for container registry authentication (cbci-sec-reg) for CI builds agents."
  default     = false
  type        = bool
}

variable "reg_secret_ns" {
  description = "Agent namespace to allocate cbci-sec-reg secret. It is required when create_reg_secret is enabled."
  default     = "cbci"
  type        = string
  validation {
    condition     = length(trimspace(var.reg_secret_ns)) > 0
    error_message = "Agent namespace must not be an empty string."
  }
}

variable "reg_secret_auth" {
  description = "Registry server authentication details for cbci-sec-reg secret. It is required when create_reg_secret is enabled."
  type        = map(string)
  default = {
    server   = "my-registry.acme:5000"
    username = "foo"
    password = "changeme1234"
    email    = "foo.bar@acme.com"
  }
  validation {
    condition     = contains(keys(var.reg_secret_auth), "server") && contains(keys(var.reg_secret_auth), "username") && contains(keys(var.reg_secret_auth), "password") && contains(keys(var.reg_secret_auth), "email")
    error_message = "The reg_secret_auth must contain the following keys: server, username, password, and email."
  }
  validation {
    condition     = length(var.reg_secret_auth) == 4
    error_message = "The reg_secret_auth must contain 4 keys."
  }
}

variable "prometheus_target" {
  description = "Creates a service monitor to discover the CloudBees CI Prometheus target dynamically. It is designed to be enabled with the AWS EKS Terraform Addon Kube Prometheus Stack."
  default     = false
  type        = bool
}
