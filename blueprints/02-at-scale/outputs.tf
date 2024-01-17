
output "export_kubeconfig" {
  description = "Export KUBECONFIG environment variable to access the K8s API."
  value       = "export KUBECONFIG=${local.kubeconfig_file_path}"
}

output "add_kubeconfig" {
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

output "cbci_general_password" {
  description = "Operation Center Service Initial Admin Password for CloudBees CI Add-on. Additionally, there are developer and guest users using the same password."
  value       = "kubectl get secret cbci-secrets -n ${module.eks_blueprints_addon_cbci.cbci_namespace} -o jsonpath='{.data.secJenkinsPass}' | base64 -d"
}

output "cjoc_url" {
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

output "s3_cbci_arn" {
  description = "CBCI s3 Bucket Arn"
  value       = module.cbci_s3_bucket.s3_bucket_arn
}

output "s3_cbci_name" {
  description = "CBCI s3 Bucket Name. It is required by CloudBees CI for Workspace Cacthing and Artifact Manager"
  value       = local.bucket_name
}

output "velero_backup_team_a" {
  description = "Force to create a velero backup from schedulle for Team A. It can be applicable for rest of schedulle backups."
  value       = "velero backup create --from-schedule ${local.velero_bk_demo} --wait"
}

output "velero_restore_team_a" {
  description = "Restore Team A from backup. It can be applicable for rest of schedulle backups."
  value       = "kubectl delete all -n ${module.eks_blueprints_addon_cbci.cbci_namespace} -l tenant=team-a; kubectl delete pvc -n ${module.eks_blueprints_addon_cbci.cbci_namespace} -l tenant=team-a; kubectl delete ep -n ${module.eks_blueprints_addon_cbci.cbci_namespace} -l tenant=team-a; velero restore create --from-schedule ${local.velero_bk_demo}"
}

output "prometheus_dashboard" {
  description = "Access to prometheus dashbaords."
  value       = "kubectl port-forward svc/kube-prometheus-stack-prometheus 50001:9090 -n kube-prometheus-stack"
}

output "grafana_dashboard" {
  description = "Access to grafana dashbaords."
  value       = "kubectl port-forward svc/kube-prometheus-stack-grafana 50002:80 -n kube-prometheus-stack"
}
