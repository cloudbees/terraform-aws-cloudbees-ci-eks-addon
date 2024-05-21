
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

variable "gh_user" {
  description = "GitHub User for CloudBees Operation Center credential GH-User-token that is created via Casc."
  default     = "exampleUser"
  type        = string
}

variable "gh_token" {
  description = "GitHub Token for CloudBees Operation Center credential GH-User-token that is created via Casc."
  default     = "ExampleToken1234"
  type        = string
}