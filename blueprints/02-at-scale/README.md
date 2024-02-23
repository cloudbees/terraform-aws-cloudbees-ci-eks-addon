# CloudBees CI blueprint add-on: At scale 

Once you have familiarized yourself with [CloudBees CI blueprint add-on: Get started](../01-getting-started/README.md), this blueprint presents a scalable architecture and configuration by adding:

- An [Amazon Elastic File System (Amazon EFS) drive](https://aws.amazon.com/efs/) that is required by CloudBees CI High Availability/Horizontal Scalability (HA/HS) controllers and is optional for non-HA/HS controllers.
- An [Amazon Simple Storage Service (Amazon S3) bucket](https://aws.amazon.com/s3/) to store assets from applications like CloudBees CI, Velero, and Fluent Bit.
- [Amazon Elastic Kubernetes Service (Amazon EKS) managed node groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html) for different workloads: CI applications, CI on-demand agents, CI spot agents, and Kubernetes applications.
- [Amazon CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html) to explode control plane logs and Fluent Bit logs.
- The following [Amazon EKS blueprints add-ons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/):

  | Amazon EKS blueprints add-ons                                                                                            | Description                                                                                                                                                                                  |
  |--------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
  | [AWS EFS CSI Driver](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-efs-csi-driver/)       | Connects the Amazon Elastic File System (Amazon EFS) drive to the Amazon EKS cluster.                                                                                                        |
  | [AWS for Fluent Bit](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-for-fluentbit/)        | Acts as an applications log router for log observability in CloudWatch.                                                                                                                      |
  | [Cluster Autoscaler](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/cluster-autoscaler/)       | Watches Amazon EKS managed node groups to accomplish [CloudBees CI auto-scaling nodes on EKS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/eks-auto-scaling-nodes). |
  | [Kube Prometheus Stack](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/kube-prometheus-stack/) | Used for metrics observability.                                                                                                                                                              |
  | [Metrics Server](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/metrics-server/)               | This is a requirement for CloudBees CI HA/HS controllers for horizontal pod autoscaling.                                                                                                     |
  | [Velero](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/velero/)                               | Backs up and restores Kubernetes resources and volume snapshots, which is only compatible with Amazon Elastic Block Store (Amazon EBS).                                                      |

- Cloudbees CI uses [Configuration as Code (CasC)](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/casc-intro) to enable [exciting new features for streamlined DevOps](https://www.cloudbees.com/blog/cloudbees-ci-exciting-new-features-for-streamlined-devops) and other enterprise features, such as [CloudBees CI hibernation](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#_hibernation_in_managed_masters).
  - The operations center configuration is hosted in [cloudbees/casc-oc-cloudbees-ci-eks-addon](https://github.com/cloudbees/casc-mc-cloudbees-ci-eks-addon) and deployed using the [CasC Bundle Retriever](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/bundle-retrieval-scm).
  - Managed controller configurations are hosted in [cloudbees/casc-mm-cloudbees-ci-eks-addon](https://github.com/cloudbees/casc-mm-cloudbees-ci-eks-addon) and managed from the operations center using [source control management (SCM)](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/add-bundle#_adding_casc_bundles_from_an_scm_tool).
  - The managed controllers are using [CasC bundle inheritance](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/advanced#_configuring_bundle_inheritance_with_casc) (refer to [bp02.parent](https://github.com/cloudbees/casc-mc-cloudbees-ci-eks-addon/tree/main/bp02.parent)). This "parent" bundle is inherited by two types of "child" controller bundles: `ha` and `none-ha`, to accommodate [considerations about HA controllers](https://docs.cloudbees.com/docs/cloudbees-ci/latest/ha-install-guide/#_considerations_about_high_availability_ha).

> [!TIP]
> A [resource group](https://docs.aws.amazon.com/ARG/latest/userguide/resource-groups.html) is also included, to get a full list of all resources created by this blueprint.

## Architecture

> [!NOTE]
> - Node groups use [Graviton Processor](https://aws.amazon.com/ec2/graviton/) to ensure the best balance between price and performance for cloud workloads running on Amazon Elastic Compute Cloud (Amazon EC2).
> - Amazon S3 storage permissions for workspace caching and the artifact manager are based on an [instance profile](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html) rather than creating a user with AWS Identity and Access Management (IAM) permissions. Therefore, it is expected that credentials validation from CloudBees CI will fail.

![Architecture](img/at-scale.architect.drawio.svg)

### Kubernetes cluster

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
| cbci_agents_pods | Get a list of agents pods running the cbci-agents namespace. |
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

When preparing to deploy, you must [customize the secrets file](#customize-secrets-file) and [update Amazon S3 bucket settings](#update-amazon-s3-bucket-settings).

> [!TIP]
> To understand the minimum required settings, refer to [Get started - Deploy](../01-getting-started/README.md#deploy).

### Customize secrets file

You must first customize your secrets file by copying the contents of [secrets-values.yml.example](k8s/secrets-values.yml.example) to `secrets-values.yml`. This provides [Docker secrets](https://github.com/jenkinsci/configuration-as-code-plugin/blob/master/docs/features/secrets.adoc#docker-secrets) that can be consumed by CasC.

### Update Amazon S3 bucket settings

Since the Terraform variable `suffix` is used for this blueprint, you must update the Amazon S3 bucket name for CloudBees CI controllers and the Amazon S3 bucket for the backup controller cluster operations. To update the Amazon S3 bucket name, you have the following options:

 - [Option 1: Update Amazon S3 bucket name using CasC](#option-1-update-amazon-s3-bucket-name-using-casc)
 - [Option 2: Update Amazon S3 bucket name using the CloudBees CI UI](#option-2-update-amazon-s3-bucket-name-using-the-cloudbees-ci-ui)

#### Option 1: Update Amazon S3 bucket name using CasC

>[!IMPORTANT]
> This option can only be used before the blueprint has been deployed.

1. Create a fork from the [cloudbees/casc-mc-cloudbees-ci-eks-addon](https://github.com/cloudbees/casc-mc-cloudbees-ci-eks-addon) GitHub repo to your GitHub organization and make any necessary edits to the controller CasC bundle (for example, add `cbci_s3` to the [bp02.parent/variables/variables.yaml](https://github.com/cloudbees/casc-mc-cloudbees-ci-eks-addon/blob/main/bp02.parent/variables/variables.yaml) file). 
2. Commit and push your changes to the forked repo in your organization.
3. Create a fork from the [cloudbees/casc-oc-cloudbees-ci-eks-addon](https://github.com/cloudbees/casc-oc-cloudbees-ci-eks-addon) GitHub repo to your GitHub organization and make any necessary edits to the operations center CasC bundle (for example, add `scm_casc_mc_store` to the [bp02/variables/variables.yaml](https://github.com/cloudbees/casc-oc-cloudbees-ci-eks-addon/blob/main/bp02/variables/variables.yaml) and [bp02/items/items-folder-admin.yaml](https://github.com/cloudbees/casc-oc-cloudbees-ci-eks-addon/blob/main/bp02/items/items-folder-admin.yaml) files). 
4. Commit and push your changes to the forked repo in your organization.
5. In the [k8s/cbci-values.yml](k8s/cbci-values.yml) Helm file, update the `OperationsCenter.CasC.Retriever.scmRepo` field based on the files in this blueprint. 
6. Save the file and issue the `terraform apply` command.

#### Option 2: Update Amazon S3 bucket name using the CloudBees CI UI

> [!IMPORTANT]
> - This option can only be used after the blueprint is deployed.
> - If using CasC, the declarative definition overrides any configuration updates that are made in the UI the next time the controller is restarted.

1. Sign in to the CloudBees CI controller UI.
2. Navigate to **Manage Jenkins > AWS > Amazon S3 Bucket Access settings**, update the **S3 Bucket Name**, and select **Save**.
3. Sign in to the CloudBees CI operations center UI as a user with **Administer** privileges.
   Note that access to back up jobs is restricted to admin users via role-based access control (RBAC).
4. From the operations center dashboard, select **All** to view all folders on the operations center.  
5. Navigate to the **admin** folder, and then select the **backup-all-controllers** Cluster Operations job.
6. From the left pane, select **Configure**.
7. Update the **S3 Bucket Name**, and then select **Save**.

## Validate

Once the blueprint has been deployed, you can validate it.

### Kubeconfig

Once the resources have been created, a `kubeconfig` file is created in the [/k8s](k8s) folder. Issue the following command to define the [KUBECONFIG](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#the-kubeconfig-environment-variable) environment variable to point to the newly generated file:

  ```sh
  eval $(terraform output --raw kubeconfig_export)
  ```

### CloudBees CI

1. Complete the steps to [validate CloudBees CI](../01-getting-started/README.md#cloudbees-ci), if you have not done so already.

2. Authentication in this blueprint uses three types of personas, each with a different authorization level. Each persona uses a different username, but has the same password. The authorization level defines a set of permissions configured using [RBAC](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-secure-guide/rbac). Additionally, the operations center and controller use [single sign-on (SS0)](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-secure-guide/using-sso). Issue the following command to retrieve the password:

    ```sh
    eval $(terraform output --raw cbci_general_password)
    ```

3. CasC is enabled for the [operations center](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/) (`cjoc`) and [controllers](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/) (`team-b` and `team-c-ha`). `team-a` is not using CasC, to illustrate the difference between the two approaches. Issue the following command to verify that all controllers are in a `Running` state:

    ```sh
    eval $(terraform output --raw cbci_controllers_pods)
    ```
   If successful, it should indicate that 2 replicas are running for `team-c-ha` since [CloudBees CI HA/HS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/ha-install-guide/) is enabled on this controller.

4. Issue the following command to verify that horizontal pod autoscaling is enabled for `team-c-ha`:

   ```sh
   eval $(terraform output --raw cbci_controller_c_hpa)
   ```

5. Issue the following command to retrieve an [API token](https://docs.cloudbees.com/docs/cloudbees-ci-api/latest/api-authentication) for the `admin` user with the correct permissions for the required actions:

   ```sh
   eval $(terraform output --raw cbci_oc_export_admin_crumb) && \
   eval $(terraform output --raw cbci_oc_export_admin_api_token) && \
   printenv | grep CBCI_ADMIN_TOKEN
   ```

   If the command is not successful, issue the following command to validate that DNS propagation has completed:
   
   ```sh
   eval $(terraform output --raw cbci_liveness_probe_ext)
   ```
6. Once you have retrieved the API token, issue the following command to remotely trigger the `ws-cache` Pipeline from `team-b` using the [POST queue for hibernation API endpoint](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#_post_queue_for_hibernation):

   ```sh
    eval $(terraform output --raw cbci_controller_b_hibernation_post_queue_ws_cache)
   ```

    If successful, an `HTTP/2 201` response is returned, indicating the REST API call has been correctly received by the CloudBees CI controller.

7. Issue the following command to trigger the build and schedule an agent pod to run the Pipeline code:

   ```sh
    eval $(terraform output --raw cbci_agents_pods)
   ```
8. In the CloudBees CI UI, sign on to the `team-b` controller.
9. Navigate to the `ws-cache` Pipeline and select the first build, indicated by the `#1` build number.
10. Select [CloudBees Pipeline Explorer](https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/cloudbees-pipeline-explorer-plugin) and examine the build logs.

> [!NOTE]
> - This Pipeline uses [CloudBees Workspace Caching](https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/cloudbees-cache-step). Once the second build is complete, you can find the read cache operation at the beginning of the build logs and the write cache operation at the end of the build logs.
> - If build logs contains `Failed to upload cache`, it is likely related to a `suffix` in your Terraform variables, and the recommendations from the [Deploy](#deploy) section were not followed.
> - Transitions to the hibernation state may happen if the defined [grace period](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#_configuring_hibernation) of inactivity (idle) has been reached.

### Back up and restore

For backup and restore operations, you can use the [preconfigured CloudBees CI Cluster Operations job](#create-daily-backups-using-a-cloudbeees-ci-cluster-operations-job) to automatically perform a daily backup, which can be used for Amazon EFS and Amazon EBS storage. 

[Velero](#create-a-velero-backup) is an alternative for services that use Amazon EBS as storage. Velero not only takes a backup of the PVC snapshots, but also takes a backup of any other defined Kubernetes resources.

> [!NOTE]
> There is no alternative for services using Amazon EFS storage. Although [AWS Backup](https://aws.amazon.com/backup/) includes this Amazon EFS drive as a protected resource, there is not currently a best practice to dynamically restore Amazon EFS PVCs. For more information, refer to [Issue 39](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/issues/39).

#### Create daily backups using a CloudBeees CI Cluster Operations job

The [CloudBees Backup plugin](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/cloudbees-backup-plugin) is enabled for all controllers and the operations center using [Amazon S3 as storage](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/cloudbees-backup-plugin#_amazon_s3). The preconfigured **backup-all-controllers** [Cluster Operations](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/cluster-operations) job is scheduled to run daily from the operations center to back up all controllers.

To view the **backup-all-controllers** job:

1. Sign in to the CloudBees CI operations center UI. Note that access to back up jobs is restricted to admin users via RBAC.
2. From the operations center dashboard, select **All** to view all folders on the operations center.
3. Navigate to the **admin** folder, and then select the **backup-all-controllers** Cluster Operations job.

> [!NOTE]
> If a build fails, it is likely related to a `suffix` that is included in your Terraform variables, and the recommendations from the [Deploy](#deploy) section were not followed.

#### Create a Velero backup

Issue the following command to create a Velero backup schedule for `team-a` (this can be also applied to `team-b`):

   ```sh
   eval $(terraform output --raw velero_backup_schedule_team_a)
   ```

Or, issue the following command to take a Velero back up for a specific point in time for `team-a`:

   ```sh
   eval $(terraform output --raw velero_backup_on_demand_team_a)
   ```

#### Restore from a Velero backup

1. Make updates on the `team-a` controller (for example, add some jobs). 
2. Take a backup including the update that you made.
3. Remove the latest update (for example, remove the jobs that you added). 
4. Issue the following command to restore the controller from the last backup:

   ```sh
   eval $(terraform output --raw velero_restore_team_a)
   ```

### Metrics

The [CloudBees Prometheus Metrics plugin](https://docs.cloudbees.com/docs/cloudbees-ci/latest/monitoring/prometheus-plugin) exposes [Jenkins Metrics](https://plugins.jenkins.io/metrics/) for Prometheus.

1. Issue the following command to verify that the CloudBees CI targets are connected to Prometheus:

   ```sh
   eval $(terraform output --raw prometheus_active_targets) | jq '.data.activeTargets[] | select(.labels.container=="jenkins" or .labels.job=="cjoc") | {job: .labels.job, instance: .labels.instance, status: .health}'
   ```

2. Issue the following command to access Kube Prometheus Stack dashboards from your web browser and verify that [Jenkins metrics](https://plugins.jenkins.io/metrics/) are available.

     ```sh
   eval $(terraform output --raw prometheus_dashboard)
   ```  
      If successful, the Prometheus dashboard should be available at `http://localhost:50001`.

3. Issue the following command to access Grafana dashboards at `localhost:50002`. For the username, use `admin` and set the password using the `grafana_admin_password` terraform variable:

   ```sh
    eval $(terraform output --raw grafana_dashboard)
    ```  
      If successful, the Grafana dashboard should be available at `http://localhost:50002`.


### Logs

For application logs, Fluent Bit acts as a router.
- Short-term application logs live in the [Amazon CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html) group, under `/aws/eks/<CLUSTER_NAME>/aws-fluentbit-logs` and contains log streams for all the Kubernetes services running in the cluster, including CloudBees CI applications.

  ```sh
    eval $(terraform output --raw aws_logstreams_fluentbit) | jq '.[] '
  ```

- Long-term application logs live in an Amazon S3 bucket.

For CloudBees CI build logs:

- Short-term build logs live in the CloudBees CI controller and are managed using the [Build Discarder](https://plugins.jenkins.io/build-discarder/) Jenkins plugin, which is installed and configured using CasC.
- Long-term logs can be handled (like any other artifact that is sent to an Amazon S3 bucket) using the [Artifact Manager on Amazon S3](https://plugins.jenkins.io/artifact-manager-s3/) Jenkins plugin, which is installed and configured by CasC.

## Destroy

To tear down and remove the resources created in the blueprint, refer to [Amazon EKS Blueprints for Terraform - Destroy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy).

## Additional resources

The following videos provide more insights regarding the capabilities presented in this blueprint:

[![Getting Started with CloudBees CI High Availability](https://img.youtube.com/vi/Qkf9HaA2wio/0.jpg)](https://www.youtube.com/watch?v=Qkf9HaA2wio)

[![Troubleshooting Pipelines With CloudBees Pipeline Explorer](https://img.youtube.com/vi/OMXm6eYd1EQ/0.jpg)](https://www.youtube.com/watch?v=OMXm6eYd1EQ)

[![Troubleshooting Pipelines With CloudBees Pipeline Explorer](https://img.youtube.com/vi/ESU9oN9JUCw/0.jpg)](https://www.youtube.com/watch?v=ESU9oN9JUCw)

[![How to Monitor Jenkins With Grafana and Prometheus](https://img.youtube.com/vi/3H9eNIf9KZs/0.jpg)](https://www.youtube.com/watch?v=3H9eNIf9KZs)