
variable "tags" {
  description = "Tags to apply to resources."
  default     = {}
  type        = map(string)
}

variable "hosted_zone" {
  description = "Amazon Route 53 hosted zone. CloudBees CI applications are configured to use subdomains in this hosted zone."
  type        = string
}

variable "trial_license" {
  description = "CloudBees CI trial license details for evaluation."
  type        = map(string)
}

variable "suffix" {
  description = "Unique suffix to assign to all resources. When adding the suffix, changes are required in CloudBees CI for the validation phase."
  default     = ""
  type        = string
  validation {
    condition     = length(var.suffix) <= 10
    error_message = "The suffix can contain 10 characters or less."
  }
}

variable "grafana_admin_password" {
  description = "Grafana admin password."
  default     = "change.me"
  type        = string
}
