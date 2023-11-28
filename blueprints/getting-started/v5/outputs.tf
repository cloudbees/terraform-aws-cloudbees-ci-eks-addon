
output "export_kubeconfig" {
  description = "Export KUBECONFIG environment variable to access the EKS cluster."
  value       = "export KUBECONFIG=${local.kubeconfig_file_path}"
}

output "eks_bp_addon_cbci_helm" {
  description = "Helm configuration for CloudBees CI Add-on. It is accesible only via state files."
  value       = module.eks_blueprints_addon_cbci.merged_helm_config
  sensitive   = true
}

output "eks_bp_addon_cbci_namepace" {
  description = "Namespace for CloudBees CI Add-on."
  value       = module.eks_blueprints_addon_cbci.cloudbees_ci_namespace
}

output "eks_bp_addon_cbci_oc_pod" {
  description = "Operation Center Pod for CloudBees CI Add-on."
  value       = module.eks_blueprints_addon_cbci.cloudbees_ci_oc_pod
}

output "eks_bp_addon_cbci_oc_ing" {
  description = "Operation Center Ingress for CloudBees CI Add-on."
  value       = module.eks_blueprints_addon_cbci.cloudbees_ci_oc_ing
}

output "eks_bp_addon_cbci_liveness_probe_int" {
  description = "Operation Center Service Internal Liveness Probe for CloudBees CI Add-on."
  value       = module.eks_blueprints_addon_cbci.cloudbees_ci_liveness_probe
}

output "eks_bp_addon_cbci_liveness_probe_ext" {
  description = "Operation Center Service External Liveness Probe for CloudBees CI Add-on."
  value       = "curl -sSf ${local.cjoc_url}/whoAmI/api/json > /dev/null"
}

output "eks_bp_addon_cbci_initial_admin_password" {
  description = "Operation Center Service Initial Admin Password for CloudBees CI Add-on."
  value       = module.eks_blueprints_addon_cbci.cloudbees_ci_initial_admin_password
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.acm.acm_certificate_arn
}

output "vpc_arn" {
  description = "VPC ID"
  value       = module.vpc.vpc_arn
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cjoc_url" {
  description = "URL of the CloudBees CI Operations Center"
  value       = local.cjoc_url
}