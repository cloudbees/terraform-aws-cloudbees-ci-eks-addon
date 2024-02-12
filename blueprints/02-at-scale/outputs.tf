
output "kubeconfig_export" {
  description = "Export KUBECONFIG environment variable to access the K8s API."
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

output "cbci_general_password" {
  description = "Operation Center Service Initial Admin Password for CloudBees CI Add-on. Additionally, there are developer and guest users using the same password."
  value       = "kubectl get secret cbci-secrets -n ${module.eks_blueprints_addon_cbci.cbci_namespace} -o jsonpath='{.data.secJenkinsPass}' | base64 -d"
}

output "cbci_oc_url" {
  description = "URL of the CloudBees CI Operations Center for CloudBees CI Add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_oc_url
}

output "cbci_oc_export_admin_crumb" {
  description = "Export Operation Center Admin Crumb to access to the API REST when CSRF is enabled."
  value       = "export CBCI_ADMIN_CRUMB=$(curl -s '${module.eks_blueprints_addon_cbci.cbci_oc_url}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)' --cookie-jar /tmp/cookies.txt --user admin:$(kubectl get secret cbci-secrets -n cbci -o jsonpath='{.data.secJenkinsPass}' | base64 -d))"
}

output "cbci_oc_export_admin_api_token" {
  description = "Export Operation Center Admin API Token to access to the API REST when CSRF is enabled. It expects CBCI_ADMIN_CRUMB as environment variable."
  value       = "export CBCI_ADMIN_TOKEN=$(curl -s '${module.eks_blueprints_addon_cbci.cbci_oc_url}/user/admin/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken' --user admin:$(kubectl get secret cbci-secrets -n cbci -o jsonpath='{.data.secJenkinsPass}' | base64 -d)  --data 'newTokenName=kb-token' --cookie /tmp/cookies.txt -H $CBCI_ADMIN_CRUMB | jq -r .data.tokenValue)"
}

output "cbci_oc_take_backups" {
  description = "OC Cluster Operation Build to take on demand backup. It expects CBCI_ADMIN_TOKEN as environment variable."
  value       = "curl -i -XPOST -u admin:$CBCI_ADMIN_TOKEN ${module.eks_blueprints_addon_cbci.cbci_oc_url}/job/admin/job/backup-all-controllers/build"
}

output "cbci_controllers_pods" {
  description = "Operation Center Pod for CloudBees CI Add-on."
  value       = "kubectl get pods -n ${module.eks_blueprints_addon_cbci.cbci_namespace} -l com.cloudbees.cje.type=master"
}

output "cbci_controller_c_hpa" {
  description = "Team C Horizontal Pod Autoscaling."
  value       = "kubectl get hpa team-c-ha -n ${module.eks_blueprints_addon_cbci.cbci_namespace}"
}

output "cbci_controller_b_hibernation_post_queue_ws_cache" {
  description = "Team B Hibernation Monitor Endpoint to Build Workspace Cache. It expects CBCI_ADMIN_TOKEN as environment variable."
  value       = "curl -i -XPOST -u admin:$CBCI_ADMIN_TOKEN ${local.hibernation_monitor_url}/hibernation/queue/team-b/job/ws-cache/build"
}

output "cbci_agents_pods" {
  description = "Get a list of agents pods running the cbci-agents namespace."
  value       = "kubectl get pods -n cbci-agents -l jenkins=slave"
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

output "efs_arn" {
  description = "EFS ARN."
  value       = module.efs.arn
}

output "efs_access_points" {
  description = "EFS Access Points."
  value       = "aws efs describe-access-points --file-system-id ${module.efs.id} --region ${local.region}"
}

output "aws_backup_efs_protected_resource" {
  description = "AWS Backup Protected Resource descriction for EFS Drive."
  value       = "aws backup describe-protected-resource --resource-arn ${module.efs.arn} --region ${local.region}"
}

output "aws_logstreams_fluentbit" {
  description = "AWS CloudWatch Log Streams from FluentBit."
  value       = "aws logs describe-log-streams --log-group-name /aws/eks/${local.cluster_name}/aws-fluentbit-logs --order-by LastEventTime --no-descending --query 'logStreams[?creationTime > `${local.epoch_millis}` ]' --region ${local.region}"
}

output "velero_backup_schedule_team_a" {
  description = "Create velero backup schedulle for Team A, deleting existing one (if exists). It can be applied for other controllers using EBS."
  value       = "velero schedule delete ${local.velero_bk_demo} --confirm || true; velero create schedule ${local.velero_bk_demo} --schedule='@every 30m' --ttl 2h --include-namespaces ${module.eks_blueprints_addon_cbci.cbci_namespace} --exclude-resources pods,events,events.events.k8s.io --selector tenant=team-a"
}

output "velero_backup_on_demand_team_a" {
  description = "Take an on-demand velero backup from the schedulle for Team A. "
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

output "prometheus_active_targets" {
  description = "Check Active Prometheus Targets from Operation Center."
  value       = "kubectl exec -n cbci -ti cjoc-0 --container jenkins -- curl -sSf kube-prometheus-stack-prometheus.kube-prometheus-stack.svc.cluster.local:9090/api/v1/targets"
}

output "grafana_dashboard" {
  description = "Access to grafana dashbaords."
  value       = "kubectl port-forward svc/kube-prometheus-stack-grafana 50002:80 -n kube-prometheus-stack"
}
