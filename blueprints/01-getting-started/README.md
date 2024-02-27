# CloudBees CI blueprint add-on: Get started

Get started with the [CloudBees CI on modern platforms in Amazon Elastic Kubernetes Service (Amazon EKS)](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/) by running this blueprint, which only installs the product and its [prerequisites](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/installing-eks-using-helm#_prerequisites), to help you understand the minimum setup:

- Amazon Web Services (AWS) certificate manager
- The following [Amazon EKS blueprints add-ons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/):
  - [AWS Load Balancer Controller](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-load-balancer-controller/)
  - [ExternalDNS](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/external-dns/)
  - [Amazon Elastic Block Store (Amazon EBS) Container Storage Interface (CSI) driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html), to allocate Amazon EBS volumes for hosting [$JENKINS_HOME](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/jenkins-home).

> [!TIP]
> A [resource group](https://docs.aws.amazon.com/ARG/latest/userguide/resource-groups.html) is added, to get a full list with all resources created by this blueprint.

## Architecture

> [!NOTE]
> Node groups use an [AWS Graviton Processor](https://aws.amazon.com/ec2/graviton/) to ensure the best balance between price and performance for cloud workloads running on Amazon Elastic Compute Cloud (Amazon EC2).

![Architecture](img/getting-started.architect.drawio.svg)

### Kubernetes cluster

![Architecture](img/getting-started.k8s.drawio.svg)

## Terraform documentation

<!-- BEGIN_TF_DOCS -->
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| hosted_zone | Route 53 Hosted Zone. CloudBees CI Apps is configured to use subdomains in this Hosted Zone. | `string` | n/a | yes |
| trial_license | CloudBees CI Trial license details for evaluation. | `map(string)` | n/a | yes |
| suffix | Unique suffix to be assigned to all resources. | `string` | `""` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| acm_certificate_arn | ACM certificate ARN |
| cbci_helm | Helm configuration for CloudBees CI Add-on. It is accesible only via state files. |
| cbci_initial_admin_password | Operation Center Service Initial Admin Password for CloudBees CI Add-on. |
| cbci_liveness_probe_ext | Operation Center Service External Liveness Probe for CloudBees CI Add-on. |
| cbci_liveness_probe_int | Operation Center Service Internal Liveness Probe for CloudBees CI Add-on. |
| cbci_namespace | Namespace for CloudBees CI Add-on. |
| cbci_oc_ing | Operation Center Ingress for CloudBees CI Add-on. |
| cbci_oc_pod | Operation Center Pod for CloudBees CI Add-on. |
| cbci_oc_url | URL of the CloudBees CI Operations Center for CloudBees CI Add-on. |
| eks_cluster_arn | EKS cluster ARN |
| kubeconfig_add | Add Kubeconfig to local configuration to access the K8s API. |
| kubeconfig_export | Export KUBECONFIG environment variable to access to access the K8s API. |
| vpc_arn | VPC ID |
<!-- END_TF_DOCS -->

## Deploy

When preparing to deploy, you must complete the following steps:

1. Customize your Terraform values by copying `.auto.tfvars.example` to `.auto.tfvars`.
2. Initialize the root module and any associated configuration for providers.
3. Create the resources and deploy CloudBees CI to an EKS cluster. Refer to [Amazon EKS Blueprints for Terraform - Deploy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy).

For more information, refer to [The Core Terraform Workflow](https://www.terraform.io/intro/core-workflow) documentation.

## Validate

Once the blueprint has been deployed, you can validate it.

### Kubeconfig

Once the resources have been created, a `kubeconfig` file is created in the [/k8s](k8s) folder. Issue the following command to define the [KUBECONFIG](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#the-kubeconfig-environment-variable) environment variable to point to the newly generated file:

  ```sh
  eval $(terraform output --raw kubeconfig_export)
  ```

  If the command is successful, no output is returned.

### CloudBees CI

Once you can access the Kubernetes API from your terminal, complete the following steps.

1. Issue the following command to verify that the CloudBees CI operations center pod is in a `Running` state:

    ```sh
    eval $(terraform output --raw cbci_oc_pod)
    ```

2. Issue the following command to verify that the Ingress is ready and has assigned a valid `ADDRESS`:

    ```sh
    eval $(terraform output --raw cbci_oc_ing)
    ```

3. Issue the following command to verify that the operations center service is running from inside the Kubernetes cluster:

    ```sh
    eval $(terraform output --raw cbci_liveness_probe_int)
    ```

    If the command is successful, no output is returned.

4. Issue the following command to verify that the operations center service is running from outside the Kubernetes cluster:

    ```sh
    eval $(terraform output --raw cbci_liveness_probe_ext)
    ```

    If the command is successful, no output is returned.

5. DNS propagation may take several minutes. Once propagation is complete, issue the following command, copy the output, and then paste it into a web browser.

    ```sh
    terraform output cbci_oc_url
    ```

6. Paste the output of the previous command into your browser to access the CloudBees CI setup wizard to complete the CloudBees CI operations center installation.

7. Issue the following command to retrieve the first administrative user password (required):

    ```sh
    eval $(terraform output --raw cbci_initial_admin_password)
    ```

## Destroy

To tear down and remove the resources created in the blueprint, complete the steps for [Amazon EKS Blueprints for Terraform - Destroy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy).
