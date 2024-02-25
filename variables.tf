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
    error_message = "The cert_arn should start with ARN."
  }
}

variable "trial_license" {
  description = "CloudBees CI trial license details for evaluation."
  type        = map(string)
}

variable "create_k8s_secrets" {
  description = "Create the Kubernetes secret cbci-secrets. It can be consumed by CasC."
  default     = false
  type        = bool
}

variable "k8s_secrets_file" {
  description = "Secrets file .yml path containing the secrets names:values for cbci-secrets."
  default     = "secrets-values.yml"
  type        = string
}

variable "prometheus_target" {
  description = "Create resources to be uses CloudBees CI as Prometheus Target."
  default     = false
  type        = bool
}
