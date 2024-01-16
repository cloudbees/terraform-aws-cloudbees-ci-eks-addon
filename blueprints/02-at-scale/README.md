# CloudBees CI Add-on at scale Blueprint

Once you have familiarized yourself with the [Getting Started blueprint](../01-getting-started/README.md), this blueprint explodes additional **[Amazon EKS Addons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/)** to present a more scalable architecture and configuration:

- [Cluster Autoscaler](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/cluster-autoscaler/) to accomplish [CloudBees auto-scaling nodes on EKS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/eks-auto-scaling-nodes).
- [EFS CSI Driver](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-efs-csi-driver/). It can be used by non-HA/HS (optional) and it is required by HA/HS CBCI Controllers.
- [Metrics Server](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/metrics-server/). It is required by CBCI HA/HS Controllers for Horizontal Pod Autoscaling.
- [Velero](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/velero/). It is used for [Backup and Restoring K8s resources and EBS volume snapshots within the CloudBees CI namespace](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/velero-dr). EFS Storage uses [AWS Backup](https://aws.amazon.com/backup/).
- [Kube Prometheus Stack](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/kube-prometheus-stack/) for observability CloudBees CI Add-on by following a similar approach to [How to Monitor Jenkins With Grafana and Prometheus 🎥](https://www.youtube.com/watch?v=3H9eNIf9KZs) but relying on the [CloudBees Prometheus Metrics plugin](https://docs.cloudbees.com/docs/cloudbees-ci/latest/monitoring/prometheus-plugin).

Additionally, it uses [CloudBees Configuration as Code](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/casc-intro) for configuring the [Operation Center](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/) and [Controllers](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/) enabling:

- [New Features for Streamlined DevOps](https://www.cloudbees.com/blog/cloudbees-ci-exciting-new-features-for-streamlined-devops): [CloudBees CI HA/HS 🎥](https://www.youtube.com/watch?v=Qkf9HaA2wio) and [CloudBees CI Workspace Cathing in s3 🎥](https://www.youtube.com/watch?v=ESU9oN9JUCw) and [Cloudbees CI Pipeline Explorer 🎥](https://www.youtube.com/watch?v=OMXm6eYd1EQ). The last one also enables the [Artifact s3 Manager 🎥](https://www.youtube.com/watch?v=u6LF-T-daS4) as a dependency and it helps to store intermediate artifacts out of the Controllers.
- [CloudBees CI Hibernation](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#_hibernation_in_managed_masters) for saving Cloud Billing costs.

> [!NOTE]
> - For s3 storage permissions for Workspace caching and Artifact Manager is based on [Instance Profile](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html) rather than creating an User with IAM permissions. Then, it is expected that Credentials validation fails from CloudBees CI.
> - There are two option to prevent from posible `node affinity conflict` during controllers restarts when using EBS volumens: make [topology aware volume to the same AZs](https://repost.aws/knowledge-center/eks-topology-aware-volumes), or designing Autoscaling Groups following what is explained in the AWS article [Creating Kubernetes Auto Scaling Groups for Multiple Availability Zones](https://aws.amazon.com/blogs/containers/amazon-eks-cluster-multi-zone-auto-scaling-groups/) (one ASG per AZ for EBS volume and one single ASG per Multiple AZ for EFS volumes). At the moment of publishing this blueprints, `terraform-aws-modules/eks/aws` does not support `availability_zones` atribute for `aws_autoscaling_group` resource, then the first option is implemented.

## Architecture

![Architecture](img/at-scale.architect.drawio.svg)

### Kubernetes Cluster

![Architecture](img/at-scale.k8s.drawio.svg)

## Prerequisites

Refer to the [Getting Started Blueprint - Prerequisites](../01-getting-started/README.md#prerequisites) section.

## Terraform Docs

<!-- BEGIN_TF_DOCS -->
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| domain_name | Desired domain name (e.g. example.com) used as suffix for CloudBees CI subdomains (e.g. cjoc.example.com). It requires to be mapped within an existing Route 53 Hosted Zone. | `string` | n/a | yes |
| temp_license | Temporary license details. | `map(string)` | n/a | yes |
| grafana_admin_password | Grafana admin password. | `string` | `"change.me"` | no |
| suffix | Unique suffix to be assigned to all resources | `string` | `""` | no |
| tags | Tags to apply to resources. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| acm_certificate_arn | ACM certificate ARN |
| add_kubeconfig | Add Kubeconfig to local configuration to access the K8s API. |
| cbci_helm | Helm configuration for CloudBees CI Add-on. It is accesible only via state files. |
| cbci_initial_admin_password | Operation Center Service Initial Admin Password for CloudBees CI Add-on. Additionally, there are developer and guest users using the same password. |
| cbci_liveness_probe_ext | Operation Center Service External Liveness Probe for CloudBees CI Add-on. |
| cbci_liveness_probe_int | Operation Center Service Internal Liveness Probe for CloudBees CI Add-on. |
| cbci_namespace | Namespace for CloudBees CI Add-on. |
| cbci_oc_ing | Operation Center Ingress for CloudBees CI Add-on. |
| cbci_oc_pod | Operation Center Pod for CloudBees CI Add-on. |
| cjoc_url | URL of the CloudBees CI Operations Center for CloudBees CI Add-on. |
| eks_cluster_arn | EKS cluster ARN |
| export_kubeconfig | Export KUBECONFIG environment variable to access the K8s API. |
| grafana_dashboard | Access to grafana dashbaords. |
| prometheus_dashboard | Access to prometheus dashbaords. |
| s3_cbci_arn | CBCI s3 Bucket Arn |
| s3_cbci_name | CBCI s3 Bucket Name. It is required by CloudBees CI for Workspace Cacthing and Artifact Manager |
| velero_backup_team_a | Force to create a velero backup from schedulle for Team A. It can be applicable for rest of schedulle backups. |
| velero_restore_team_a | Restore Team A from backup. It can be applicable for rest of schedulle backups. |
| vpc_arn | VPC ID |
<!-- END_TF_DOCS -->

## Deploy

Refer to the [Getting Started Blueprint - Prerequisites](../01-getting-started/README.md#deploy) section.

Additionally, the following is required:

- Customize your secrets file by copying `secrets-values.yml.example` to `secrets-values.yml`.
- In the case of using the terraform variable `suffix` for this blueprint, the Amazon `S3 Bucket Access settings` > `S3 Bucket Name` requires to be updated:
  - via UI (temporal update): Go to `Manage Jenkins` in the Controller > `AWS` > `Amazon S3 Bucket Access settings` > `S3 Bucket Name`.
  - via Casc (permanent update):
    - Make a fork from [cloudbees/casc-mm-cloudbees-ci-eks-addon](https://github.com/cloudbees/casc-mm-cloudbees-ci-eks-addon) to your organization, and update accordingly `cbci_s3` in `bp02.parent/variables/variables.yaml` file. Save and Push.
    - Make a fork from [cloudbees/casc-oc-cloudbees-ci-eks-addon](https://github.com/cloudbees/casc-mm-cloudbees-ci-eks-addon) to your organization, and update accordingly `scm_casc_mm_store` in `bp02/variables/variables.yaml` file. Save and Push.

> [!IMPORTANT]
> The declarative Casc defition overrides anything modified at UI at the next time the Controller is restarted.

## Validate

Refer to the [Getting Started Blueprint - Prerequisites](../01-getting-started/README.md#validate) section. In addition, you can validate the following:

- Velero puntual Backup on time for Team A. Note also there is a scheduled backup process.

  ```sh
  eval $(terraform output --raw velero_backup_team_a)
  ```

- Velero Restore process: Make any update on `team-a` (e.g.: adding some jobs), take a backup including the update, remove the latest update (e.g.: removing the jobs) and then restore it from the last backup as follows.

  ```sh
  eval $(terraform output --raw velero_restore_team_a)
  ```

- Check the CloudBees CI Targets are connected to Prometheus.

  ```sh
  kubectl exec -n cbci -ti cjoc-0 --container jenkins -- curl -sSf kube-prometheus-stack-prometheus.kube-prometheus-stack.svc.cluster.local:9090/api/v1/targets?state=active | jq '.data.activeTargets[] | select(.labels.container=="jenkins" or .labels.job=="cjoc") | {job: .labels.job, instance: .labels.instance, status: .health}'
  ```

- Access to Kube Prometheus Stack dashboards from your web browser (Check that [jenkins metrics](https://plugins.jenkins.io/metrics/) are available)

  - Prometheus

  ```sh
  eval $(terraform output --raw prometheus_dashboard)
  ```  

  - Grafana

  ```sh
  eval $(terraform output --raw grafana_dashboard)
  ```  

- Once the `Amazon S3 Bucket Access settings` > `S3 Bucket Name` is configured correctly (see [Deploy](#deploy) section), you can validate the Workspace Caching and Artifact Manager are working as expected running the jobs `ws-cache`, `upstream-artifact` and finally `downstream-artifact`. Note that team-b uses hibernation

  ```sh
  curl -i -XPOST -u admin:"$(kubectl get secret cbci-secrets -n cbci -o jsonpath='{.data.secJenkinsPass}' | base64 -d)" "http://$ROUTE_53_DOMAIN/hibernation/queue/team-b/job/ws-cache/build?delay=180sec"
  ```

## Destroy

Refer to the [Getting Started Blueprint - Prerequisites](../01-getting-started/README.md#destroy) section.
