
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
  description = "Unique suffix to assign to all resources."
  default     = ""
  type        = string
  validation {
    condition     = length(var.suffix) <= 10
    error_message = "The suffix cannot contain more than 10 characters."
  }
}

variable "ci" {
  description = "Running in a CI service versus running locally. False when running locally, true when running in a CI service."
  default     = false
  type        = bool
}

#Check number of AZ: aws ec2 describe-availability-zones --region var.aws_region
variable "aws_region" {
  description = "AWS region to deploy resources to. It requires at minimun 2 AZs."
  type        = string
  default     = "us-west-2"
}
