# Copyright (c) CloudBees, Inc.

output "argocd_gitops_config" {
  description = "Configuration used for managing the add-on with ArgoCD"
  value       = var.manage_via_gitops ? { enable = true } : null
}

output "merged_helm_config" {
  description = "(merged) Helm Config for CloudBees CI"
  value       = helm_release.cloudbees_ci
}
