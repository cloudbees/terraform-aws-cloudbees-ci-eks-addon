# CloudBees CI Add-on getting started Blueprint

Get started with the [CloudBees CI on Modern in EKS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/) by running this blueprint which just installs the product and its [prerequisites](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/installing-eks-using-helm#_prerequisites) to help you understand the minimum requirements.

- AWS Certificate Manager
- **[Amazon EKS Addons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/)**:
  - [AWS Load Balancer Controller](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-load-balancer-controller/)
  - [External DNS](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/external-dns/)
  - [EBS CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html) to allocate EBS volumes for hosting [JENKINS_HOME](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/jenkins-home).

> [!TIP]
> A [Resource Group](https://docs.aws.amazon.com/ARG/latest/userguide/resource-groups.html) is added to get a full list with all resources created by this blueprint.

## Architecture

![Architecture](img/getting-started.architect.drawio.svg)

### Kubernetes Cluster

![Architecture](img/getting-started.k8s.drawio.svg)

## Terraform Docs

<!-- BEGIN_TF_DOCS -->
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| domain_name | Desired domain name (e.g. example.com) used as suffix for CloudBees CI subdomains (e.g. cjoc.example.com). It requires to be mapped within an existing Route 53 Hosted Zone. | `string` | n/a | yes |
| temp_license | Temporary license details | `map(string)` | n/a | yes |
| suffix | Unique suffix to be assigned to all resources | `string` | `""` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| acm_certificate_arn | ACM certificate ARN |
| add_kubeconfig | Add Kubeconfig to local configuration to access the K8s API. |
| cbci_helm | Helm configuration for CloudBees CI Add-on. It is accesible only via state files. |
| cbci_initial_admin_password | Operation Center Service Initial Admin Password for CloudBees CI Add-on. |
| cbci_liveness_probe_ext | Operation Center Service External Liveness Probe for CloudBees CI Add-on. |
| cbci_liveness_probe_int | Operation Center Service Internal Liveness Probe for CloudBees CI Add-on. |
| cbci_namespace | Namespace for CloudBees CI Add-on. |
| cbci_oc_ing | Operation Center Ingress for CloudBees CI Add-on. |
| cbci_oc_pod | Operation Center Pod for CloudBees CI Add-on. |
| cbci_oc_url | URL of the CloudBees CI Operations Center for CloudBees CI Add-on. |
| eks_cluster_arn | EKS cluster ARN |
| export_kubeconfig | Export KUBECONFIG environment variable to access to access the K8s API. |
| vpc_arn | VPC ID |
<!-- END_TF_DOCS -->

## Deploy

First of all, customize your terraform values by copying `.auto.tfvars.example` to `.auto.tfvars`.

Initialize the root module and any associated configuration for providers and finally create the resources and deploy CloudBees CI to an EKS Cluster. Please refer to [Getting Started - Amazon EKS Blueprints for Terraform - Deploy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy)

For more detailed information, see the documentation for the [Terraform Core workflow](https://www.terraform.io/intro/core-workflow).

Once deployed has finished, it is possible to check the generated AWS resources via Resource Groups.

## Validate

Once the resources have been created, note that a `kubeconfig` file has been created inside the respective `blueprint/k8s` folder. Start defining the Environment Variable [KUBECONFIG](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#the-kubeconfig-environment-variable) to point to the generated file.

  ```sh
  eval $(terraform output --raw export_kubeconfig)
  ```

Once you get access to K8s API from your terminal, validate that:

- The CloudBees Operation Center Pod is running

  ```sh
  eval $(terraform output --raw cbci_oc_pod)
  ```

- The Ingress Controller is ready and has assigned a valid `ADDRESS`

  ```sh
  eval $(terraform output --raw cbci_oc_ing)
  ```

- Check that the Operation Center Service is running from inside the K8s cluster. Successful output should be nothing in return.

  ```sh
  eval $(terraform output --raw cbci_liveness_probe_int)
  ```

- Check that the Operation Center Service is running from outside the K8s cluster. Successful output should be nothing in return.

  ```sh
  eval $(terraform output --raw cbci_liveness_probe_ext)
  ```

> [!NOTE]
> DNS propagation can take a few minutes

- Once propagation is ready, it is possible to access the CloudBees CI installation Wizard by copying the outcome of the below command in your browser.

  ```sh
  terraform output cbci_oc_url
  ```

Now that you’ve installed CloudBees CI and operations center, you’ll want to see your system in action. To do this, follow the steps explained in [CloudBees CI EKS Install Guide - Signing in to your CloudBees CI installation](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/installing-eks-using-helm#log-in). You will need the initial admin password to log in as:

  ```sh
  eval $(terraform output --raw cbci_initial_admin_password)
  ```

> [!NOTE]
> Once you can create the first admin user in the Wizard, this password will not be valid.

Finally, install the suggested plugins and create the first admin user.

## Destroy

To teardown and remove the resources created in the blueprint, the typical steps of execution are as explained in [Getting Started - Amazon EKS Blueprints for Terraform - Destroy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy)
