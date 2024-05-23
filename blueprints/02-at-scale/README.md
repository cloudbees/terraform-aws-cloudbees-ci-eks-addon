# CloudBees CI blueprint add-on: At scale

Once you have familiarized yourself with [CloudBees CI blueprint add-on: Get started](../01-getting-started/README.md), this blueprint presents a scalable architecture and configuration by adding:

- An [Amazon Elastic File System (Amazon EFS) drive](https://aws.amazon.com/efs/) that is required by CloudBees CI High Availability/Horizontal Scalability (HA/HS) controllers and is optional for non-HA/HS controllers.
- An [Amazon Simple Storage Service (Amazon S3) bucket](https://aws.amazon.com/s3/) to store assets from applications like CloudBees CI, Velero, and Fluent Bit.
- [Amazon Elastic Kubernetes Service (Amazon EKS) managed node groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html) for different workloads: CI applications, CI on-demand agents, CI spot agents, and Kubernetes applications.
- [Amazon CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html) to explode control plane logs and Fluent Bit logs.
- The following [Amazon EKS blueprints add-ons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/):

  | Amazon EKS blueprints add-ons | Description |
  |-------------------------------|-------------|
  | [AWS EFS CSI Driver](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-efs-csi-driver/)| Connects the Amazon Elastic File System (Amazon EFS) drive to the Amazon EKS cluster. |
  | [AWS for Fluent Bit](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-for-fluentbit/)| Acts as an applications log router for log observability in CloudWatch. |
  | [Cluster Autoscaler](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/cluster-autoscaler/) | Watches Amazon EKS managed node groups to accomplish [CloudBees CI auto-scaling nodes on EKS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/eks-auto-scaling-nodes). |
  | [Kube Prometheus Stack](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/kube-prometheus-stack/) | Used for metrics observability.|
  | [Metrics Server](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/metrics-server/) | This is a requirement for CloudBees CI HA/HS controllers for horizontal pod autoscaling.|
  | [Velero](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/velero/)| Backs up and restores Kubernetes resources and volume snapshots. It is only compatible with Amazon Elastic Block Store (Amazon EBS).|
  | [Bottlerocket Update Operator](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/bottlerocket/) | Coordinates Bottlerocket updates on hosts in a cluster. It is configured for CloudBees CI Applications and Agents Node Groups at a specific time according to `scheduler_cron_expression`, when the build workload is minimal (weekend). In a case where the CI service cannot be interrupted at any time by the Update Operator, it could be excluded from planned updates by removing the [bottlerocket.aws/updater-interface-version=2.0.0](https://github.com/bottlerocket-os/bottlerocket-update-operator#label-nodes) label.|

- [Amazon EKS blueprints Helm Release Add-on](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/helm-release/) is used to install the following applications:

  | Helm Chart | Description |
  |-------------------------------|-------------|
  | [Osixia Openldap](https://github.com/osixia/docker-openldap) | LDAP server. |
  | [AWS Node Termination Handler](https://github.com/aws/aws-node-termination-handler) | Gracefully handles EC2 instance shutdown within Kubernetes. Note that this add-on is not compatible with managed instance groups. For more information, refer to [issue #23](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/issues/23). |
  | [Grafana Tempo](https://github.com/osixia/docker-openldap) | Provides backend tracing for [Jenkins OpenTelemetry](https://plugins.jenkins.io/opentelemetry/). |

- Cloudbees CI uses [Configuration as Code (CasC)](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/casc-intro) (refer to the [casc](casc) folder) to enable [exciting new features for streamlined DevOps](https://www.cloudbees.com/blog/cloudbees-ci-exciting-new-features-for-streamlined-devops) and other enterprise features, such as [CloudBees CI hibernation](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#_hibernation_in_managed_masters).
  - The operations center is using the [CasC Bundle Retriever](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/bundle-retrieval-scm).
  - Managed controller configurations are managed from the operations center using [source control management (SCM)](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/add-bundle#_adding_casc_bundles_from_an_scm_tool).
  - The managed controllers are using [CasC bundle inheritance](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/advanced#_configuring_bundle_inheritance_with_casc) (refer to the [parent](casc/mc/parent) folder). This "parent" bundle is inherited by two types of "child" controller bundles: `ha` and `none-ha`, to accommodate [considerations about HA controllers](https://docs.cloudbees.com/docs/cloudbees-ci/latest/ha/ha-considerations).

> [!TIP]
> A [resource group](https://docs.aws.amazon.com/ARG/latest/userguide/resource-groups.html) is also included, to get a full list of all resources created by this blueprint.

## Architecture

> [!NOTE]
> - The CloudBees CI node groups use the following specifications:
>    - Instance type: [AWS Graviton Processor](https://aws.amazon.com/ec2/graviton/)
>    - Amazon Machine Image (AMI) type: [Bottlerocket OS](https://aws.amazon.com/bottlerocket/)
>    - The Spot agents node groups follow the principles described in [Building for Cost optimization and Resilience for EKS with Spot Instances](https://aws.amazon.com/blogs/compute/cost-optimization-and-resilience-eks-with-spot-instances/).
> - Amazon S3 storage permissions are based on an [instance profile](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html), rather than creating a user with an AWS identity and IAM permissions. It is expected that the credentials validation from CloudBees CI will fail.

![Architecture](img/at-scale.architect.drawio.svg)

### Kubernetes cluster

![Architecture](img/at-scale.k8s.drawio.svg)

## Terraform Docs

<!-- BEGIN_TF_DOCS -->
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| hosted_zone | Amazon Route 53 hosted zone. CloudBees CI applications are configured to use subdomains in this hosted zone. | `string` | n/a | yes |
| trial_license | CloudBees CI trial license details for evaluation. | `map(string)` | n/a | yes |
| gh_token | GitHub token for the CloudBees operations center credential GH-User-token, that is created via CloudBees CasC. | `string` | `"ExampleToken1234"` | no |
| gh_user | GitHub User for CloudBees Operation Center credential GH-User-token that is created via Casc. | `string` | `"exampleUser"` | no |
| suffix | Unique suffix to assign to all resources. When adding the suffix, changes are required in CloudBees CI for the validation phase. | `string` | `""` | no |
| tags | Tags to apply to resources. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| acm_certificate_arn | AWS Certificate Manager (ACM) certificate for Amazon Resource Names (ARN). |
| aws_backup_efs_protected_resource | AWS description for the Amazon EFS drive that is used to back up protected resources. |
| aws_logstreams_fluentbit | AWS CloudWatch log streams from Fluent Bit. |
| cbci_agents_events_stopping | Retrieves a list of agent pods running in the agents namespace. |
| cbci_agents_pods | Retrieves a list of agent pods running in the agents namespace. |
| cbci_controller_b_hibernation_post_queue_ws_cache | team-b hibernation monitor endpoint to the build workspace cache. It expects CBCI_ADMIN_TOKEN as the environment variable. |
| cbci_controller_c_hpa | team-c horizontal pod autoscaling. |
| cbci_controllers_pods | Operations center pod for the CloudBees CI add-on. |
| cbci_helm | Helm configuration for the CloudBees CI add-on. It is accessible via state files only. |
| cbci_liveness_probe_ext | Operations center service external liveness probe for the CloudBees CI add-on. |
| cbci_liveness_probe_int | Operations center service internal liveness probe for the CloudBees CI add-on. |
| cbci_namespace | Namespace for the CloudBees CI add-on. |
| cbci_oc_export_admin_api_token | Exports the operations center cbci_admin_user API token to access the REST API when CSRF is enabled. It expects CBCI_ADMIN_CRUMB as the environment variable. |
| cbci_oc_export_admin_crumb | Exports the operations center cbci_admin_user crumb, to access the REST API when CSRF is enabled. |
| cbci_oc_ing | Operations center Ingress for the CloudBees CI add-on. |
| cbci_oc_pod | Operations center pod for the CloudBees CI add-on. |
| cbci_oc_take_backups | Operations center cluster operations build for the on-demand back up. It expects CBCI_ADMIN_TOKEN as the environment variable. |
| cbci_oc_url | Operations center URL for the CloudBees CI add-on. |
| efs_access_points | Amazon EFS access points. |
| efs_arn | Amazon EFS ARN. |
| eks_cluster_arn | Amazon EKS cluster ARN. |
| global_password | Random string that is used as the global password. |
| grafana_dashboard | Provides access to Grafana dashboards. |
| kubeconfig_add | Add kubeconfig to the local configuration to access the Kubernetes API. |
| kubeconfig_export | Export the KUBECONFIG environment variable to access the Kubernetes API. |
| ldap_admin_password | LDAP password for the cbci_admin_user user for the CloudBees CI add-on. Check .docker/ldap/data.ldif. |
| prometheus_active_targets | Checks active Prometheus targets from the operations center. |
| prometheus_dashboard | Provides access to Prometheus dashboards. |
| s3_cbci_arn | CloudBees CI Amazon S3 bucket ARN. |
| s3_cbci_name | CloudBees CI Amazon S3 bucket name. It is required by CloudBees CI for workspace caching and artifact management. |
| velero_backup_on_demand | Takes an on-demand Velero backup from the schedule for the selected controller that is using block storage. |
| velero_backup_schedule | Creates a Velero backup schedule for the selected controller that is using block storage, and then deletes the existing schedule, if it exists. |
| velero_restore | Restores the selected controller that is using block storage from a backup. |
| vpc_arn | VPC ID. |
<!-- END_TF_DOCS -->

## Deploy

When preparing to deploy, you must complete the following steps:

1. Customize your Terraform values by copying `.auto.tfvars.example` to `.auto.tfvars`.
2. Initialize the root module and any associated configuration for providers.
3. Create the resources and deploy CloudBees CI to an EKS cluster. Refer to [Amazon EKS Blueprints for Terraform - Deploy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy).

For more information, refer to [The Core Terraform Workflow](https://www.terraform.io/intro/core-workflow) documentation.

> [!TIP]
> The `deploy` phase can be orchestrated via the companion [Makefile](../../Makefile).

## Validate

Once the blueprint has been deployed, you can validate it.

### Kubeconfig

Once the resources have been created, a `kubeconfig` file is created in the [/k8s](k8s) folder. Issue the following command to define the [KUBECONFIG](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#the-kubeconfig-environment-variable) environment variable to point to the newly generated file:

   ```sh
   eval $(terraform output --raw kubeconfig_export)
   ```

   If the command is successful, no output is returned.

### CloudBees CI

1. Complete the steps to [validate CloudBees CI](../01-getting-started/README.md#cloudbees-ci), if you have not done so already.

2. Authentication in this blueprint is based on LDAP using the `cn` user (available in [k8s/openldap-stack-values.yml](./k8s/openldap-stack-values.yml)) and the global password. The authorization level defines a set of permissions configured using [RBAC](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-secure-guide/rbac). Additionally, the operations center and controller use [single sign-on (SS0)](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-secure-guide/using-sso). Issue the following command to retrieve the global password:

   ```sh
   eval $(terraform output --raw global_password)
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

5. Issue the following command to retrieve an [API token](https://docs.cloudbees.com/docs/cloudbees-ci-api/latest/api-authentication) for the `admin_cbci_a` user with the correct permissions for the required actions:

   ```sh
   eval $(terraform output --raw cbci_oc_export_admin_crumb) && \
   eval $(terraform output --raw cbci_oc_export_admin_api_token) && \
   printenv | grep CBCI_ADMIN_TOKEN
   ```

   If the command is not successful, issue the following command to validate that DNS propagation has completed:

   ```sh
   eval $(terraform output --raw cbci_liveness_probe_ext)
   ```

6. Once you have retrieved the API token, issue the following command to remotely trigger the `ws-cache` pipeline from `team-b` using the [POST queue for hibernation API endpoint](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#_post_queue_for_hibernation):

   ```sh
   eval $(terraform output --raw cbci_controller_b_hibernation_post_queue_ws_cache)
   ```

   If successful, an `HTTP/2 201` response is returned, indicating the REST API call has been correctly received by the CloudBees CI controller.

7. Right after triggering the build, issue the following to validate pod agent provisioning to build the pipeline code:

   ```sh
   eval $(terraform output --raw cbci_agents_pods)
   ```

8. In the CloudBees CI UI, sign in to the `team-b` controller.
9. Navigate to the `ws-cache` pipeline and select the first build, indicated by the `#1` build number.
10. Select [CloudBees Pipeline Explorer](https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/cloudbees-pipeline-explorer-plugin) and examine the build logs.

> [!NOTE]
> - This pipeline uses [CloudBees Workspace Caching](https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/cloudbees-cache-step). Once the second build is complete, you can find the read cache operation at the beginning of the build logs and the write cache operation at the end of the build logs.
> - If build logs contains `Failed to upload cache`, it is likely related to a `suffix` in your Terraform variables, and the recommendations from the [Deploy](#deploy) section were not followed.
> - Transitions to the hibernation state may happen if the defined [grace period](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#_configuring_hibernation) of inactivity (idle) has been reached.

#### Back up and restore

For backup and restore operations, you can use the [preconfigured CloudBees CI Cluster Operations job](#create-daily-backups-using-a-cloudbees-ci-cluster-operations-job) to automatically perform a daily backup, which can be used for Amazon EFS and Amazon EBS storage.

[Velero](#create-a-velero-backup-schedule) is an alternative for services only for controllers using Amazon EBS. Velero commands and configuration in this blueprint follow [Using Velero back up and restore Kubernetes cluster resources](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/velero-dr).

> [!NOTE]
> - An installation that has been completely converted to CasC may not need traditional backups; a restore operation could consist simply of running a CasC bootstrap script. This is only an option for a customer who has translated every significant system setting and job configuration to CasC. Even then it may be desirable to perform a filesystem-level restore from backup in order to preserve transient data such as build history.
> - There is no alternative for services using Amazon EFS storage. Although [AWS Backup](https://aws.amazon.com/backup/) includes this Amazon EFS drive as a protected resource, there is not currently a best practice to dynamically restore Amazon EFS PVCs. For more information, refer to [Issue 39](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/issues/39).

##### Create daily backups using a CloudBees CI Cluster Operations job

The [CloudBees Backup plugin](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/cloudbees-backup-plugin) is enabled for all controllers and the operations center using [Amazon S3 as storage](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/cloudbees-backup-plugin#_amazon_s3). The preconfigured **backup-all-controllers** [Cluster Operations](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/cluster-operations) job is scheduled to run daily from the operations center to back up all controllers.

To view the **backup-all-controllers** job:

1. Sign in to the CloudBees CI operations center UI as a user with **Administer** privileges. Note that access to back up jobs is restricted to admin users via RBAC.
2. From the operations center dashboard, select **All** to view all folders on the operations center.
3. Navigate to the **admin** folder, and then select the **backup-all-controllers** Cluster Operations job.

> [!NOTE]
> If a build fails, it is likely related to a `suffix` that is included in your Terraform variables, and the recommendations from the [Deploy](#deploy) section were not followed.

##### Create a Velero backup schedule

Issue the following command to create a Velero backup schedule for selected controller `team-b` (this can also be applied to `team-a`):

   ```sh
   eval $(terraform output --raw velero_backup_schedule)
   ```

##### Take an on-demand Velero backup

>[!NOTE]
> When using this CloudBees CI add-on, you must [create at least one Velero backup schedule](#create-a-velero-backup-schedule) prior to taking an on-demand Velero backup.

Issue the following command to take an on-demand Velero backup for a specific point in time for `team-b` based on the schedule definition:

   ```sh
   eval $(terraform output --raw velero_backup_on_demand)
   ```

##### Restore from a Velero on-demand backup

1. Make updates on the `team-b` controller (for example, add some jobs and generate builds).
2. [Take an on-demand Velero backup](#take-an-on-demand-velero-backup), including the updates that you made.
3. Remove the latest update (for example, remove jobs you create and build on existing jobs).
4. Manage `team-b` > Deprovision the controller.
5. Issue the following command to restore the controller from the last backup:

   ```sh
   eval $(terraform output --raw velero_restore)
   ```

### Observability

#### Metrics and Tracing

Grafana is used to visualize and query:

- [Jenkins Metrics](https://plugins.jenkins.io/metrics/) that are stored in Prometheus.
- [Jenkins Tracing via OpenTelemetry](https://plugins.jenkins.io/opentelemetry/) that stored into Grafana Tempo.

1. Issue the following command to verify that the CloudBees CI targets are connected to Prometheus:

   ```sh
   eval $(terraform output --raw prometheus_active_targets) | jq '.data.activeTargets[] | select(.labels.container=="jenkins") | {job: .labels.job, instance: .labels.instance, status: .health}'
   ```

2. Issue the following command to access Kube Prometheus Stack dashboards from your web browser and verify that [Jenkins metrics](https://plugins.jenkins.io/metrics/) are available.

   ```sh
   eval $(terraform output --raw prometheus_dashboard)
   ```  

   If successful, the Prometheus dashboard should be available at `http://localhost:50001` and you can view the configured alerts for CloudBees CI.

3. Issue the following command to access Grafana dashboards at `localhost:50002`. For the username, use `admin` and set the password using the `grafana_admin_password` terraform variable:

   ```sh
   eval $(terraform output --raw grafana_dashboard)
   ```

   If successful, the Grafana dashboard should be available at `http://localhost:50002`.

   - For Jenkins Metrics Dashboards navigate to **Dashboards > CloudBees CI**. Then, select the controller pod to view the metrics. The following image shows metrics for team-b.

   ![CloudBees CI Dashboard](img/observability/cbci-dashboard.png)

   - For Tracing Data, navigate to **Home > Explore > Select Tempo > Select `Query Type: Search`**. Then, select the `service name: jenkins` and the desired `Span Name` to `Run Query`. The following image shows an example of the ws-cache pipeline build.

   ![CloudBees CI Tracing Example](img/observability/cbci-tracing-example.png)

#### Logs

For application logs, Fluent Bit acts as a router.

- Short-term application logs live in the [Amazon CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html) group, under `/aws/eks/<CLUSTER_NAME>/aws-fluentbit-logs` and contains log streams for all the Kubernetes services running in the cluster, including CloudBees CI applications and agents. The following image shows an example of team b controller logs.

   ```sh
   eval $(terraform output --raw aws_logstreams_fluentbit) | jq '.[] '
   ```

   ![CloudBees CI Logs Example](img/observability/cbci-fluenbit-example.png)

- Long-term application logs live in an Amazon S3 bucket.

For CloudBees CI build logs:

- Short-term build logs live in the CloudBees CI controller and are managed using the [Build Discarder](https://plugins.jenkins.io/build-discarder/) Jenkins plugin, which is installed and configured using CasC.
- Long-term logs can be handled (like any other artifact that is sent to an Amazon S3 bucket) using the [Artifact Manager on Amazon S3](https://plugins.jenkins.io/artifact-manager-s3/) Jenkins plugin, which is installed and configured by CasC.

## Destroy

To tear down and remove the resources created in the blueprint, refer to [Amazon EKS Blueprints for Terraform - Destroy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy).

> [!TIP]
> The `destroy` phase can be orchestrated via the companion [Makefile](../../Makefile).
