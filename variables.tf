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

variable "hostname" {
  description = "Route53 Hosted zone name"
  type        = string
}

variable "cert_arn" {
  description = "Certificate ARN from AWS ACM"
  type        = string

  validation {
    condition     = can(regex("^arn", var.cert_arn))
    error_message = "For the cert_arn should start with arn."
  }
}

variable "temp_license" {
  description = "Temporary license details"
  type        = map(string)
}

variable "secrets_file" {
  description = "Secrets file yml path containing the secrets names:values to create the Kubernetes secret cbci-secrets. It can be mounted for Casc"
  default     = "secrets-values.yml"
  type        = string
}
