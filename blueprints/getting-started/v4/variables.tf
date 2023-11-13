
variable "tags" {
  description = "Tags to apply to resources"
  default     = {}
  type        = map(string)
}

variable "domain_name" {
  description = "An existing domain name maped to a Route 53 Hosted Zone"
  type        = string
  validation {
    condition     = trim(var.domain_name, " ") != ""
    error_message = "Domain name must not be en empty string."
  }
}

variable "temp_license" {
  description = "Temporary license details"
  type        = map(string)
  default = {
    first_name = "User Name Example"
    last_name  = "User Last Name Example"
    email      = "example@mail.com"
    company    = "Example Inc."
  }
}