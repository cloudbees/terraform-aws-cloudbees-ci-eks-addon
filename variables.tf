# Copyright (c) CloudBees, Inc.

variable "helm_config" {
  description = "CloudBees CI Helm chart configuration"
  type        = any
  default = {
    values = [
      <<-EOT
      EOT
    ]
  }
}

variable "hosted_zone" {
  description = "Route53 Hosted zone name"
  type        = string
  validation {
    condition     = trim(var.hosted_zone, " ") != ""
    error_message = "Host name must not be en empty string."
  }
}

variable "cert_arn" {
  description = "Certificate ARN from AWS ACM"
  type        = string

  validation {
    condition     = can(regex("^arn", var.cert_arn))
    error_message = "For the cert_arn should start with arn."
  }
}

variable "trial_license" {
  description = "CloudBees CI Trial license details for evaluation."
  type        = map(string)
}

variable "secrets_file" {
  description = "Secrets file yml path containing the secrets names:values to create the Kubernetes secret cbci-secrets. It can be consumed by Casc as Docker secrets."
  default     = "secrets-values.yml"
  type        = string
}
