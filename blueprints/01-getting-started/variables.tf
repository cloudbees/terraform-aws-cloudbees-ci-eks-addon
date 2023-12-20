variable "name" {
  description = "Unique name to be assigned to all resources"
  default     = ""
  type        = string
}

variable "region" {
  description = "The region from which this module will be executed."
  type        = string
  validation {
    condition     = can(regex("(us(-gov)?|ap|ca|cn|eu|sa)-(central|(north|south)?(east|west)?)-\\d", var.region))
    error_message = "Variable var: region is not valid."
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  default     = {}
  type        = map(string)
}

variable "domain_name" {
  description = "Desired domain name (e.g. example.com) used as suffix for CloudBees CI subdomains (e.g. cjoc.example.com). It requires to be mapped within an existing Route 53 Hosted Zone."
  type        = string
  validation {
    condition     = trim(var.domain_name, " ") != ""
    error_message = "Domain name must not be en empty string."
  }
}

variable "temp_license" {
  description = "Temporary license details"
  type        = map(string)
}

variable "k8s_version" {
  description = "EKS cluster version, refer to: https://docs.cloudbees.com/docs/cloudbees-common/latest/supported-platforms/cloudbees-ci-cloud#_kubernetes "
  type        = string
  default     = "1.26"
}

variable "vpc_cidr" {
  description = "CIDR for the EKS cluster VPC"
  type = string
  default = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be valid IPv4 CIDR."
  }
}