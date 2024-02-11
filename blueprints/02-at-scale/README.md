# CloudBees CI Add-on at scale Blueprint

Once you have familiarized yourself with the [Getting Started blueprint](../01-getting-started/README.md), this one presents a scalable architecture and configuration by adding:

- An [EFS Drive](https://aws.amazon.com/efs/) that can be used by non-HA/HS controllers (optional) and is required by HA/HS CBCI Controllers. It is managed by [AWS Backup](https://aws.amazon.com/backup/) for Backup and Restore.
- An [s3 Bucket](https://aws.amazon.com/s3/) to store assets from applications like CloudBees CI and Velero.
- [EKS Managed node groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html) for different workloads: CI Applications, CI On-Demand Agent, CI Spot Agents and K8s applications.
- [CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html) for Control plane logs and Applications Container Insights.
- The following **[Amazon EKS Addons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/)**:
  - EKS Managed node groups are watched by [Cluster Autoscaler](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/cluster-autoscaler/) to accomplish [CloudBees auto-scaling nodes on EKS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/eks-auto-scaling-nodes) on defined EKS Managed node groups.
  - [EFS CSI Driver](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-efs-csi-driver/) to connect EFS Drive to the EKS Cluster.
  - The [Metrics Server](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/metrics-server/) as requirement for CBCI HA/HS Controllers for Horizontal Pod Autoscaling.
  - [Velero](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/velero/) for Backup and Restore of Kubernetes Resources and Volumen snapshot (EBS compatible only).
  - [Kube Prometheus Stack](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/kube-prometheus-stack/) is used for Metrics Observability.
  - [AWS for Fluent Bit](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-for-fluentbit/) acts as an Applications log router for Log Observability in CloudWatch.
- Cloudbees CI uses [Configuration as Code](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/casc-intro) to enable [New Features for Streamlined DevOps](https://www.cloudbees.com/blog/cloudbees-ci-exciting-new-features-for-streamlined-devops) as well as other enterprise features and configurations.
  - Operation Center configuration is hosted in [cloudbees/casc-oc-cloudbees-ci-eks-addon](https://github.com/cloudbees/casc-mm-cloudbees-ci-eks-addon) and deployed via [Bundle Retrival Strategy](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/bundle-retrieval-scm).
  - Controller configurations are hosted in [cloudbees/casc-mm-cloudbees-ci-eks-addon](https://github.com/cloudbees/casc-mm-cloudbees-ci-eks-addon) and managed from the Operation Center via [SCM configuration](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/add-bundle#_adding_casc_bundles_from_an_scm_tool).
    - Controllers use [bundle inheritance](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/advanced#_configuring_bundle_inheritance_with_casc) see `bp02.parent`. This bundle is inherited by two types of controller bundles `ha` and `none-ha`, to accommodate different configurations required for HA/HS controllers.

> [!TIP]
> A [Resource Group](https://docs.aws.amazon.com/ARG/latest/userguide/resource-groups.html) is added to get a full list with all resources created by this blueprint.

## Architecture

![Architecture](img/at-scale.architect.drawio.svg)

Node Groups use [Graviton Processor](https://aws.amazon.com/ec2/graviton/) to ensure the best balance price and performance for cloud workloads running on Amazon EC2.

For s3 storage permissions for Workspace caching and Artifact Manager is based on [Instance Profile](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html) rather than creating a User with IAM permissions. Then, it is expected that Credentials validation fails from CloudBees CI.

### Kubernetes Cluster

![Architecture](img/at-scale.k8s.drawio.svg)

## Terraform Docs

<!-- BEGIN_TF_DOCS -->
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| hosted_zone | Route 53 Hosted Zone. CloudBees CI Apps is configured to use subdomains in this Hosted Zone. | `string` | n/a | yes |
| trial_license | CloudBees CI Trial license details for evaluation. | `map(string)` | n/a | yes |
| grafana_admin_password | Grafana admin password. | `string` | `"change.me"` | no |
| suffix | Unique suffix to be assigned to all resources. When adding suffix, it requires chnages in CloudBees CI for the validation phase. | `string` | `""` | no |
| tags | Tags to apply to resources. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| acm_certificate_arn | ACM certificate ARN |
| aws_backup_efs_protected_resource | AWS Backup Protected Resource descriction for EFS Drive. |
| aws_logstreams_fluentbit | AWS CloudWatch Log Streams from FluentBit. |
| cbci_controller_b_hibernation_post_queue_ws_cache | Team B Hibernation Monitor Endpoint to Build Workspace Cache. It expects CBCI_ADMIN_TOKEN as environment variable. |
| cbci_controller_c_hpa | Team C Horizontal Pod Autoscaling. |
| cbci_controllers_pods | Operation Center Pod for CloudBees CI Add-on. |
| cbci_general_password | Operation Center Service Initial Admin Password for CloudBees CI Add-on. Additionally, there are developer and guest users using the same password. |
| cbci_helm | Helm configuration for CloudBees CI Add-on. It is accesible only via state files. |
| cbci_liveness_probe_ext | Operation Center Service External Liveness Probe for CloudBees CI Add-on. |
| cbci_liveness_probe_int | Operation Center Service Internal Liveness Probe for CloudBees CI Add-on. |
| cbci_namespace | Namespace for CloudBees CI Add-on. |
| cbci_oc_export_admin_api_token | Export Operation Center Admin API Token to access to the API REST when CSRF is enabled. It expects CBCI_ADMIN_CRUMB as environment variable. |
| cbci_oc_export_admin_crumb | Export Operation Center Admin Crumb to access to the API REST when CSRF is enabled. |
| cbci_oc_ing | Operation Center Ingress for CloudBees CI Add-on. |
| cbci_oc_pod | Operation Center Pod for CloudBees CI Add-on. |
| cbci_oc_take_backups | OC Cluster Operation Build to take on demand backup. It expects CBCI_ADMIN_TOKEN as environment variable. |
| cbci_oc_url | URL of the CloudBees CI Operations Center for CloudBees CI Add-on. |
| efs_access_points | EFS Access Points. |
| efs_arn | EFS ARN. |
| eks_cluster_arn | EKS cluster ARN |
| grafana_dashboard | Access to grafana dashbaords. |
| kubeconfig_add | Add Kubeconfig to local configuration to access the K8s API. |
| kubeconfig_export | Export KUBECONFIG environment variable to access the K8s API. |
| prometheus_active_targets | Check Active Prometheus Targets from Operation Center. |
| prometheus_dashboard | Access to prometheus dashbaords. |
| s3_cbci_arn | CBCI s3 Bucket Arn |
| s3_cbci_name | CBCI s3 Bucket Name. It is required by CloudBees CI for Workspace Cacthing and Artifact Manager |
| velero_backup_on_demand_team_a | Take an on-demand velero backup from the schedulle for Team A. |
| velero_backup_schedule_team_a | Create velero backup schedulle for Team A, deleting existing one (if exists). It can be applied for other controllers using EBS. |
| velero_restore_team_a | Restore Team A from backup. It can be applicable for rest of schedulle backups. |
| vpc_arn | VPC ID |
<!-- END_TF_DOCS -->

## Deploy

Refer to the [Getting Started Blueprint - Deploy](../01-getting-started/README.md#deploy) section.

Additionally, the following is required:

- Customize your secrets file by copying `secrets-values.yml.example` to `secrets-values.yml`. It provides [Docker secrets](https://github.com/jenkinsci/configuration-as-code-plugin/blob/master/docs/features/secrets.adoc#docker-secrets) that can be used from Casc.
- In the case of using the terraform variable `suffix` for this blueprint the following elements require to be updated: The Amazon `S3 Bucket Access settings` > `S3 Bucket Name` for CloudBees CI Controllers and The Amazon `S3 Bucket` for the Backup Controllers Cluster Operations. This can be done in two ways:
  - via Casc (**Before deploying** the blueprint):
    - Make a fork from [cloudbees/casc-mm-cloudbees-ci-eks-addon](https://github.com/cloudbees/casc-mm-cloudbees-ci-eks-addon) to your organization, and update accordingly `cbci_s3` in `bp02.parent/variables/variables.yaml` file. Save and Push.
    - Make a fork from [cloudbees/casc-oc-cloudbees-ci-eks-addon](https://github.com/cloudbees/casc-mm-cloudbees-ci-eks-addon) to your organization, and update accordingly `scm_casc_mm_store` in `bp02/variables/variables.yaml` file and `bp02/items/items-folder-admin.yaml` . Save and Push.
    - Finally, update the field `OperationsCenter.CasC.Retriever.scmRepo` from the helm file `k8s/cbci-values.yml` from the files in this blueprint. Save and `terraform apply`.
  - via GUI (**After deploying** the blueprint):
    - On CloudBes CI Controller service once is ready: Go to `Manage Jenkins` in the Controller > `AWS` > `Amazon S3 Bucket Access settings` > `S3 Bucket Name`. Save.
    - On CloudBes CI Operation Center service once is ready: Login as Admin (backup jobs are restricted to admin only using RBAC). Then, go to `admin` folder > `backup-all-controllers` configure and update `S3 Bucket Name`. Save.

> [!IMPORTANT]
> The declarative Casc defition overrides configuration updates from the UI (in case they overlap) at the next time the Controller is restarted.

## Validate

### Kubeconfig

Once the resources have been created, note that a `kubeconfig` file has been created inside the respective `blueprint/k8s` folder. Start defining the Environment Variable [KUBECONFIG](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#the-kubeconfig-environment-variable) to point to the generated file.

  ```sh
  eval $(terraform output --raw kubeconfig_export)
  ```

### CloudBees CI

- Start by referring to the [Getting Started Blueprint - Validate](../01-getting-started/README.md#validate) but this time there will be three types of personas/users with a different set of permissions configured via [RBAC](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-secure-guide/rbac) for Operation Center and Controller using [Single Sign-On](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-secure-guide/using-sso). The password for all of them is the same:

  ```sh
  eval $(terraform output --raw cbci_general_password)
  ```

- Configuration as Code (CasC) is enabled for [Operation Center](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/) (`cjoc`) and [Controllers](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/) (`team-b` and `team-c-ha`). `team-a` is not using CasC to show the difference between the two approaches. Check that all Controllers are in `Running` state.

  ```sh
  eval $(terraform output --raw cbci_controllers_pods)
  ```

- From the previous validation, it can be seen that 2 replicas are running for `team-c-ha`. This is because [CloudBees CI HA/HS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/ha-install-guide/) is enabled in this controller. See Horizontal Pod Autoscaling enabled by:

  ```sh
  eval $(terraform output --raw cbci_controller_c_hpa)
  ```

- The consecutive validations for CloudBees CI operate remotely with CloudBees CI by triggering pipeline builds (The same results could be obtained by scheduling builds manually from the GUI). Firstly, let's set the `admin` user `API Token` as an environment variable to be used in the next steps:

  ```sh
  eval $(terraform output --raw cbci_oc_export_admin_crumb) && \
    eval $(terraform output --raw cbci_oc_export_admin_api_token) && \
    printenv | grep CBCI_ADMIN_TOKEN
  ```

> [!NOTE]
> If it fails, validate the DNS propgation is completed by `eval $(terraform output --raw cbci_liveness_probe_ext)`.

- [CloudBees Workspace Caching](https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/cloudbees-cache-step), [CloudBees CI Hibernation](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#_hibernation_in_managed_masters) and [CloudBees Pipeline Explorer](https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/cloudbees-pipeline-explorer-plugin) features can be seen together in action in the pipeline `ws-cache` from `team-b`. To trigger these builds will be using the [POST queue hibernation API endpoints](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#_post_queue_for_hibernation).

  ```sh
    eval $(terraform output --raw cbci_controller_b_hibernation_post_queue_ws_cache)
  ```

The build is triggered successfully getting `HTTP/2 201` as the response from the API REST call. Now, log in `team-b` and check its build output of `ws-cache` pipeline using the capabilities CloudBees Pipeline Explorer (enabled for all Controllers using Configuration as Code).

> [!NOTE]
>
> - If build logs contains `Failed to upload cache`, likely it is related that a `suffix` is included into the your terraform vars but considerations from [Deploy](#deploy) section were not followed.
> - Transitions to the hibernation state happens after reaching the defined [Grace Period time](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#_configuring_hibernation) of inactivity (idle).

### Backups and Restore

- [CloudBees Backup plugin](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/cloudbees-backup-plugin) is enabled for all Controllers and Operation Center using [s3 as storage](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/cloudbees-backup-plugin#_amazon_s3). The backup process is scheduled to be taken daily from the Operation Center via [Cluster Operations](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/cluster-operations). It can be used for EFS and EBS Storage.

  - To take an on-demand backup for all controllers:

    ```sh
      eval $(terraform output --raw cbci_oc_take_backups)
    ```

- For Block Storage (EBS) Velero is also enabled and it is the [recommended option](https://aws.github.io/aws-eks-best-practices/upgrades/#backup-the-cluster-before-upgrading). It not only backups the pvc snapshots but also any other defined Kubernetes resources.

  - Create a Velero Backup schedule for Team A to take regular backups. This can be also applied to Team B.

    ```sh
    eval $(terraform output --raw velero_backup_schedule_team_a)
    ```

  - Velero Backup on a specific point in time for Team A. Note also there is a scheduled backup process in place.

    ```sh
    eval $(terraform output --raw velero_backup_on_demand_team_a)
    ```

  - Velero Restore process: Make any update on `team-a` (e.g.: adding some jobs), take a backup including the update, remove the latest update (e.g.: removing the jobs) and then restore it from the last backup as follows

    ```sh
    eval $(terraform output --raw velero_restore_team_a)
    ```

- However, the CloudBees Backup plugin would be the only choice for EFS Storage. At the moment of writing this blueprint, there is no Best Practice to Restore Dynamically EFS PVCs (see [Issue 39](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/issues/39)).

### Observability

- Metrics: The explanations from [How to Monitor Jenkins With Grafana and Prometheus - CloudBees TV 🎥](https://www.youtube.com/watch?v=3H9eNIf9KZs) are valid in this context but this blueprint relies on the [CloudBees Prometheus Metrics plugin](https://docs.cloudbees.com/docs/cloudbees-ci/latest/monitoring/prometheus-plugin) and not the open-source version.

  - Check the CloudBees CI Targets are connected to Prometheus.

    ```sh
    eval $(terraform output --raw prometheus_active_targets) | jq '.data.activeTargets[] | select(.labels.container=="jenkins" or .labels.job=="cjoc") | {job: .labels.job, instance: .labels.instance, status: .health}'
    ```

  - Access to Kube Prometheus Stack dashboards from your web browser (Check that [Jenkins metrics](https://plugins.jenkins.io/metrics/) are available)

    - Prometheus will be available at `http://localhost:50001` after running the following command in your host:

    ```sh
    eval $(terraform output --raw prometheus_dashboard)
    ```  

    - Grafana will be available at `http://localhost:50002` after running the following command in your host:

    ```sh
    eval $(terraform output --raw grafana_dashboard)
    ```  

- Logs:

  - Applications logs: Fluent bit acts as a router:

    - Short-term Application logs live in CloudWatch Logs Group `/aws/containerinsights/<CLUSTER_NAME>/application` can be found Log streams for all the K8s Services running in the cluster, including CloudBees CI Apps.

    ```sh
      eval $(terraform output --raw aws_logstreams_fluentbit) | jq '.[] '
    ```

    - Long-term Application logs live in a s3 Bucket

  - Build logs:

    - Short-term lives in CloudBees CI Controller and managed by [Build Discarder | Jenkins plugin](https://plugins.jenkins.io/build-discarder/) - which is installed and configured by CasC.
    - Long-term logs can be handled by [Artifact Manager on S3 | Jenkins plugin](https://plugins.jenkins.io/artifact-manager-s3/) like any other artifact to be sent to s3 Bucket - which is installed and configured by CasC.

## Destroy

Refer to the [Getting Started Blueprint - Destroy](../01-getting-started/README.md#destroy) section.

### References

The following videos extend the capabilities presented in this blueprint:

- [Getting Started With CloudBees CI High Availability - CloudBees TV 🎥](https://www.youtube.com/watch?v=Qkf9HaA2wio)
- [Troubleshooting Pipelines With CloudBees Pipeline Explorer - CloudBees TV 🎥](https://www.youtube.com/watch?v=OMXm6eYd1EQ)
- [Getting Started With CloudBees Workspace Caching on AWS S3 - CloudBees TV 🎥](https://www.youtube.com/watch?v=ESU9oN9JUCw&)
- [How to Monitor Jenkins With Grafana and Prometheus - CloudBees TV 🎥](https://www.youtube.com/watch?v=3H9eNIf9KZs)
