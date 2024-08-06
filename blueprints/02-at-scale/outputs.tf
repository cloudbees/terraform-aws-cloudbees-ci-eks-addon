output "kubeconfig_export" {
  description = "Export the KUBECONFIG environment variable to access the Kubernetes API."
  value       = "export KUBECONFIG=${local.kubeconfig_file_path}"
}

output "kubeconfig_add" {
  description = "Add kubeconfig to the local configuration to access the Kubernetes API."
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

output "cbci_oc_url" {
  description = "Operations center URL for the CloudBees CI add-on."
  value       = module.eks_blueprints_addon_cbci.cbci_oc_url
}

output "cbci_oc_export_admin_crumb" {
  description = "Exports the operations center cbci_admin_user crumb, to access the REST API when CSRF is enabled."
  value       = "export CBCI_ADMIN_CRUMB=$(curl -s '${module.eks_blueprints_addon_cbci.cbci_oc_url}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)' --cookie-jar /tmp/cookies.txt --user ${local.cbci_admin_user}:$(kubectl get secret ${module.eks_blueprints_addon_cbci.cbci_sec_casc} -n ${module.eks_blueprints_addon_cbci.cbci_namespace} -o jsonpath=${local.global_pass_jsonpath} | base64 -d))"
}

output "cbci_oc_export_admin_api_token" {
  description = "Exports the operations center cbci_admin_user API token to access the REST API when CSRF is enabled. It expects CBCI_ADMIN_CRUMB as the environment variable."
  value       = "export CBCI_ADMIN_TOKEN=$(curl -s '${module.eks_blueprints_addon_cbci.cbci_oc_url}/user/${local.cbci_admin_user}/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken' --user ${local.cbci_admin_user}:$(kubectl get secret ${module.eks_blueprints_addon_cbci.cbci_sec_casc} -n ${module.eks_blueprints_addon_cbci.cbci_namespace} -o jsonpath=${local.global_pass_jsonpath} | base64 -d)  --data 'newTokenName=kb-token' --cookie /tmp/cookies.txt -H $CBCI_ADMIN_CRUMB | jq -r .data.tokenValue)"
}

output "cbci_oc_take_backups" {
  description = "Operations center cluster operations build for the on-demand back up. It expects CBCI_ADMIN_TOKEN as the environment variable."
  value       = "curl -i -XPOST -u ${local.cbci_admin_user}:$CBCI_ADMIN_TOKEN ${module.eks_blueprints_addon_cbci.cbci_oc_url}/job/${local.cbci_admin_user}/job/backup-all-controllers/build"
}

output "cbci_controllers_pods" {
  description = "Operations center pod for the CloudBees CI add-on."
  value       = "kubectl get pods -n ${module.eks_blueprints_addon_cbci.cbci_namespace} -l com.cloudbees.cje.type=master"
}

output "cbci_controller_c_hpa" {
  description = "team-c horizontal pod autoscaling."
  value       = "kubectl get hpa team-c-ha -n ${module.eks_blueprints_addon_cbci.cbci_namespace}"
}

output "cbci_controller_b_s3_build" {
  description = "team-b hibernation monitor endpoint to the build s3-WScacheAndArtifacts. It expects CBCI_ADMIN_TOKEN as the environment variable."
  value       = "curl -i -XPOST -u ${local.cbci_admin_user}:$CBCI_ADMIN_TOKEN ${local.hibernation_monitor_url}/hibernation/queue/team-b/job/admin/job/validations/job/s3-WScacheAndArtifacts/build"
}

output "cbci_controller_c_windows_node_build" {
  description = "team-c hibernation monitor endpoint to the Windows build nodes. It expects CBCI_ADMIN_TOKEN as the environment variable."
  value       = "curl -i -XPOST -u ${local.cbci_admin_user}:$CBCI_ADMIN_TOKEN ${local.hibernation_monitor_url}/hibernation/queue/team-c-ha/job/admin/job/validations/job/windows-builds-nodes/build"
}

output "cbci_agents_pods" {
  description = "Retrieves a list of agent pods running in the agents namespace."
  value       = "kubectl get pods -n ${local.cbci_agents_ns} -l jenkins=slave"
}

output "cbci_agent_linuxtempl_events" {
  description = "Retrieves a list of events related to Linux template agents."
  value       = "kubectl get events -n ${local.cbci_agents_ns} | grep -i pod/${local.cbci_agent_linuxtempl}"
}

output "cbci_agent_windowstempl_events" {
  description = "Retrieves a list of events related to Windows template agents."
  value       = "kubectl get events -n ${local.cbci_agents_ns} | grep -i pod/${local.cbci_agent_windowstempl}"
}

output "cbci_agent_sec_reg" {
  description = "Retrieves the container registry secret deployed in the agents namespace."
  value       = "kubectl get secret ${module.eks_blueprints_addon_cbci.cbci_sec_registry} -n ${local.cbci_agents_ns} -o jsonpath='{.data.*}' | base64 -d"
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

output "s3_cbci_arn" {
  description = "CloudBees CI Amazon S3 bucket ARN."
  value       = module.cbci_s3_bucket.s3_bucket_arn
}

output "s3_cbci_name" {
  description = "CloudBees CI Amazon S3 bucket name. It is required by CloudBees CI for workspace caching and artifact management."
  value       = local.bucket_name
}

output "s3_list_objects" {
  description = "Recursively lists all objects stored in the Amazon S3 bucket."
  value       = "aws s3 ls s3://${local.bucket_name}/ --recursive"
}

output "efs_arn" {
  description = "Amazon EFS ARN."
  value       = module.efs.arn
}

output "efs_access_points" {
  description = "Amazon EFS access points."
  value       = "aws efs describe-access-points --file-system-id ${module.efs.id} --region ${var.aws_region}"
}

output "aws_backup_efs_protected_resource" {
  description = "AWS description for the Amazon EFS drive that is used to back up protected resources."
  value       = "aws backup describe-protected-resource --resource-arn ${module.efs.arn} --region ${var.aws_region}"
}

output "aws_logstreams_fluentbit" {
  description = "AWS CloudWatch log streams from Fluent Bit."
  value       = "aws logs describe-log-streams --log-group-name /aws/eks/${local.cluster_name}/aws-fluentbit-logs --order-by LastEventTime --no-descending --query 'logStreams[?creationTime > `${local.epoch_millis}` ]' --region ${var.aws_region}"
}

output "velero_backup_schedule" {
  description = "Creates a Velero backup schedule for the selected controller that is using block storage, and then deletes the existing schedule, if it exists."
  value       = "velero schedule delete ${local.velero_schedule_name} --confirm || true; velero create schedule ${local.velero_schedule_name} --schedule='@every 30m' --ttl 2h --include-namespaces ${module.eks_blueprints_addon_cbci.cbci_namespace} --exclude-resources pods,events,events.events.k8s.io -l ${local.velero_controller_backup_selector} --snapshot-volumes=true --include-cluster-resources=true"
}

output "velero_backup_on_demand" {
  description = "Takes an on-demand Velero backup from the schedule for the selected controller that is using block storage."
  value       = "velero backup create --from-schedule ${local.velero_schedule_name} --wait"
}

output "velero_restore" {
  description = "Restores the selected controller that is using block storage from a backup."
  value       = "kubectl delete all,pvc -n ${module.eks_blueprints_addon_cbci.cbci_namespace} -l ${local.velero_controller_backup_selector}; velero restore create --from-schedule ${local.velero_schedule_name} --restore-volumes=true"
}

output "prometheus_dashboard" {
  description = "Provides access to Prometheus dashboards."
  value       = "kubectl port-forward svc/kube-prometheus-stack-prometheus 50001:9090 -n kube-prometheus-stack"
}

output "prometheus_active_targets" {
  description = "Checks active Prometheus targets from the operations center."
  value       = "kubectl exec -n cbci -ti cjoc-0 --container jenkins -- curl -sSf kube-prometheus-stack-prometheus.kube-prometheus-stack.svc.cluster.local:9090/api/v1/targets"
}

output "grafana_dashboard" {
  description = "Provides access to Grafana dashboards."
  value       = "kubectl port-forward svc/kube-prometheus-stack-grafana 50002:80 -n kube-prometheus-stack"
}

output "global_password" {
  description = "Random string that is used as the global password."
  value       = "kubectl get secret ${module.eks_blueprints_addon_cbci.cbci_sec_casc} -n ${module.eks_blueprints_addon_cbci.cbci_namespace} -o jsonpath=${local.global_pass_jsonpath} | base64 -d"
}

output "vault_init" {
  description = "Inicialization of Vault Service."
  value       = "kubectl exec -it vault-0 -n ${local.vault_ns} -- vault operator init | tee ${local.vault_init_file_path} || echo \"Vault is already initialized.\""
}

output "vault_init_log_file" {
  description = "Vault Inicialization log file."
  value       = local.vault_init_file_path
}

output "vault_configure" {
  description = "Configure Vault with initial secrets and creates approle for integration with CloudBees CI (role-id and secret-id). It requires unseal keys and the root token from the vault_init output."
  value       = "bash ${local.vault_config_file_path} ${local.vault_ns}"
}

output "vault_dashboard" {
  description = "Provides access to Hashicorp Vault dashboard. It requires the root token from the vault_init output."
  value       = "kubectl port-forward svc/vault 50003:8200 -n ${local.vault_ns}"
}
