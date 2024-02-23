# Copyright (c) CloudBees, Inc.

output "merged_helm_config" {
  description = "(merged) Helm configuration for CloudBees CI."
  value       = helm_release.cloudbees_ci
}

output "cbci_namespace" {
  description = "Namespace for the CloudBees CI Addon."
  value       = helm_release.cloudbees_ci.namespace
}

output "cbci_oc_url" {
  description = "Operations center URL for the CloudBees CI Add-on using a subdomain and certificates."
  value       = "https://cjoc.${var.hosted_zone}"
}

output "cbci_domain_name" {
  description = "Amazon Route 53 domain name to host CloudBees CI services."
  value       = var.hosted_zone
}

output "cbci_oc_pod" {
  description = "Operations center pod for the CloudBees CI Add-on."
  value       = "kubectl get pod -n ${helm_release.cloudbees_ci.namespace} cjoc-0"
}

output "cbci_oc_ing" {
  description = "Operations center Ingress for the CloudBees CI Add-on."
  value       = "kubectl get ing -n ${helm_release.cloudbees_ci.namespace} cjoc"
}

output "cbci_liveness_probe_int" {
  description = "Operations center service internal liveness probe for the CloudBees CI Add-on."
  value       = "kubectl exec -n ${helm_release.cloudbees_ci.namespace} -ti cjoc-0 --container jenkins -- curl -sSf localhost:8080/whoAmI/api/json > /dev/null"
}

output "cbci_liveness_probe_ext" {
  description = "Operations center service external liveness probe for the CloudBees CI Add-on."
  value       = "curl -sSf https://cjoc.${var.hosted_zone}/whoAmI/api/json > /dev/null"
}
