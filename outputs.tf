# Copyright (c) CloudBees, Inc.

output "merged_helm_config" {
  description = "(merged) Helm Config for CloudBees CI"
  value       = helm_release.cloudbees_ci
}

output "cbci_namespace" {
  description = "Namespace for CloudBees CI Addon."
  value       = helm_release.cloudbees_ci.namespace
}

output "cbci_oc_url" {
  description = "Operation Center URL for CloudBees CI Add-on using Subdomain and Certificates."
  value       = "https://cjoc.${var.hostname}"
}

output "cbci_oc_pod" {
  description = "Operation Center Pod for CloudBees CI Add-on."
  value       = "kubectl get pod -n ${helm_release.cloudbees_ci.namespace} cjoc-0"
}

output "cbci_oc_ing" {
  description = "Operation Center Ingress for CloudBees CI Add-on."
  value       = "kubectl get ing -n ${helm_release.cloudbees_ci.namespace} cjoc"
}

output "cbci_liveness_probe_int" {
  description = "Operation Center Service Internal Liveness Probe for CloudBees CI Add-on."
  value       = "kubectl exec -n ${helm_release.cloudbees_ci.namespace} -ti cjoc-0 --container jenkins -- curl -sSf localhost:8080/whoAmI/api/json > /dev/null"
}

output "cbci_liveness_probe_ext" {
  description = "Operation Center Service External Liveness Probe for CloudBees CI Add-on."
  value       = "curl -sSf https://cjoc.${var.hostname}/whoAmI/api/json > /dev/null"
}

output "cbci_initial_admin_password" {
  description = "Operation Center Service Initial Admin Password for CloudBees CI Add-on."
  value       = "kubectl exec -n ${helm_release.cloudbees_ci.namespace} -ti cjoc-0 --container jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword &> /dev/null || echo 'N/A. Casc is enabled'"
}
