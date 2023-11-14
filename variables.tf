# Copyright (c) CloudBees, Inc.

variable "helm_config" {
  description = "CloudBees CI Helm chart configuration"
  type        = any
  default     = {}
}

variable "manage_via_gitops" {
  description = "Determines if the add-on should be managed via GitOps"
  type        = bool
  default     = false
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