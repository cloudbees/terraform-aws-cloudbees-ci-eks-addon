# Copyright (c) CloudBees, Inc.

output "merged_helm_config" {
  description = "(merged) Helm Config for CloudBees CI"
  value       = helm_release.cloudbees_ci
}