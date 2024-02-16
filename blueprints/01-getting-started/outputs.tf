
output "kubeconfig_export" {
  description = "Export KUBECONFIG environment variable to access to access the K8s API."
  value       = "export KUBECONFIG=${local.kubeconfig_file_path}"
}

output "kubeconfig_add" {
  description = "Add Kubeconfig to local configuration to access the K8s API."
  value       = "aws eks update-kubeconfig --region ${local.region} --name ${local.cluster_name}"
}

output "cbci_helm" {
  description = "Helm configuration for CloudBees CI Add-on. It is accesible only via state files."
  value       = module.eks_blueprints_addon_cbci.merged_helm_config
  sensitive   = true
}

output "cbci_namespace" {
  description = "Namespace for CloudBees CI Add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_namespace
}

output "cbci_oc_pod" {
  description = "Operation Center Pod for CloudBees CI Add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_oc_pod
}

output "cbci_oc_ing" {
  description = "Operation Center Ingress for CloudBees CI Add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_oc_ing
}

output "cbci_liveness_probe_int" {
  description = "Operation Center Service Internal Liveness Probe for CloudBees CI Add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_liveness_probe_int
}

output "cbci_liveness_probe_ext" {
  description = "Operation Center Service External Liveness Probe for CloudBees CI Add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_liveness_probe_ext
}

output "cbci_initial_admin_password" {
  description = "Operation Center Service Initial Admin Password for CloudBees CI Add-on."
  value       = "kubectl exec -n ${module.eks_blueprints_addon_cbci.cbci_namespace} -ti cjoc-0 --container jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword || echo 'Initial Admin Password was removed. It happens when you create the first admin user.'"
}

output "cbci_oc_url" {
  description = "URL of the CloudBees CI Operations Center for CloudBees CI Add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_oc_url
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
