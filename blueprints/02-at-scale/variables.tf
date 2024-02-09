
variable "tags" {
  description = "Tags to apply to resources."
  default     = {}
  type        = map(string)
}

variable "hosted_zone" {
  description = "Route 53 Hosted Zone. CloudBees CI Apps is configured to use subdomains in this Hosted Zone."
  type        = string
}

variable "trial_license" {
  description = "CloudBees CI Trial license details for evaluation."
  type        = map(string)
}

variable "suffix" {
  description = "Unique suffix to be assigned to all resources. When adding suffix, it requires chnages in CloudBees CI for the validation phase."
  default     = ""
  type        = string
  validation {
    condition     = length(var.suffix) <= 10
    error_message = "The suffix cannot have more than 10 characters."
  }
}

variable "grafana_admin_password" {
  description = "Grafana admin password."
  default     = "change.me"
  type        = string
}
