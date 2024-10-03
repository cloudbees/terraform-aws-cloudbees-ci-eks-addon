output "kubeconfig_export" {
  description = "Exports the KUBECONFIG environment variable to access the Kubernetes API."
  value       = "export KUBECONFIG=${local.kubeconfig_file_path}"
}

output "kubeconfig_add" {
  description = "Adds kubeconfig to your local configuration to access the Kubernetes API."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${local.cluster_name}"
}

output "cbci_helm" {
  description = "Helm configuration for the CloudBees CI add-on. It is accessible via state files only."
  value       = module.eks_blueprints_addon_cbci.merged_helm_config
  sensitive   = true
}

output "cbci_namespace" {
  description = "Namespace for the CloudBees CI add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_namespace
}

output "cbci_oc_pod" {
  description = "Operations center pod for the CloudBees CI add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_oc_pod
}

output "cbci_oc_ing" {
  description = "Operations center Ingress for the CloudBees CI add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_oc_ing
}

output "cbci_liveness_probe_int" {
  description = "Operations center service internal liveness probe for the CloudBees CI add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_liveness_probe_int
}

output "cbci_liveness_probe_ext" {
  description = "Operations center service external liveness probe for the CloudBees CI add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_liveness_probe_ext
}

output "cbci_initial_admin_password" {
  description = "Operations center service initial admin password for the CloudBees CI add-on."
  value       = "kubectl exec -n ${module.eks_blueprints_addon_cbci.cbci_namespace} -ti cjoc-0 --container jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword || echo 'Initial admin password was removed. This happens when you create the first admin user.'"
}

output "cbci_oc_url" {
  description = "URL of the CloudBees CI operations center for the CloudBees CI add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_oc_url
}

output "acm_certificate_arn" {
  description = "AWS Certificate Manager (ACM) certificate for Amazon Resource Names (ARN)."
  value       = module.acm.acm_certificate_arn
}

output "vpc_arn" {
  description = "VPC ID."
  value       = module.vpc.vpc_arn
}

output "eks_cluster_arn" {
  description = "Amazon EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "eks_cluster_name" {
  description = "Amazon EKS cluster Name."
  value       = module.eks.cluster_name
}
