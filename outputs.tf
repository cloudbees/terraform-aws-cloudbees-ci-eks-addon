# Copyright (c) CloudBees, Inc.

output "merged_helm_config" {
  description = "(merged) Helm Config for CloudBees CI"
  value       = helm_release.cloudbees_ci
}

output "cloudbees_ci_namespace" {
  description = "Namespace for CloudBees CI Addon."
  value       = helm_release.cloudbees_ci.namespace
}

output "cloudbees_ci_oc_pod" {
  description = "Operation Center Pod for CloudBees CI Add-on."
  value       = "kubectl get pod -n ${helm_release.cloudbees_ci.namespace} cjoc-0"
}

output "cloudbees_ci_oc_ing" {
  description = "Operation Center Ingress for CloudBees CI Add-on."
  value       = "kubectl get ing -n ${helm_release.cloudbees_ci.namespace} cjoc"
}

output "cloudbees_ci_liveness_probe" {
  description = "Operation Center Service Internal Liveness Probe for CloudBees CI Add-on."
  value       = "kubectl exec -n ${helm_release.cloudbees_ci.namespace} -ti cjoc-0 -- curl -sSf localhost:8080/whoAmI/api/json > /dev/null"
}

output "cloudbees_ci_initial_admin_password" {
  description = "Operation Center Service Initial Admin Password for CloudBees CI Add-on."
  value       = "kubectl exec -n ${helm_release.cloudbees_ci.namespace} -ti cjoc-0 -- cat /var/jenkins_home/secrets/initialAdminPassword"
}
