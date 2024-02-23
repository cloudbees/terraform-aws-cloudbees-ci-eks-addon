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
    condition     = trim(var.hosted_zone, " ") != ""
    error_message = "Host name must not be an empty string."
  }
}

variable "cert_arn" {
  description = "AWS Certificate Manager (ACM) certificate for Amazon Resource Names (ARN)."
  type        = string

  validation {
    condition     = can(regex("^arn", var.cert_arn))
    error_message = "cert_arn should start with ARN."
  }
}

variable "trial_license" {
  description = "CloudBees CI trial license details for evaluation."
  type        = map(string)
}

variable "secrets_file" {
  description = "Secrets file .yml path containing the secrets names:values to create the Kubernetes secret, cbci-secrets. It can be consumed by CasC as Docker secrets."
  default     = "secrets-values.yml"
  type        = string
}
