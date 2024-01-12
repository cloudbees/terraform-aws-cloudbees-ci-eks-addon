# CloudBees CI Add-on getting started Blueprint

Get started with the [CloudBees CI on Modern in EKS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/) by running this blueprint which just installs the product and its [prerequisites](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/installing-eks-using-helm#_prerequisites) to help you to understand what are the minimum requirements.

- AWS Certificate Manager
- **[Amazon EKS Addons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/)**:
  - [AWS Load Balancer Controller](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-load-balancer-controller/)
  - [External DNS](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/external-dns/)
  - [EBS CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html) to allocate EBS volumes for hosting [JENKINS_HOME](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/jenkins-home).

## Architecture

![Architecture](img/getting-started.architect.drawio.svg)

### Kubernetes Cluster

![Architecture](img/getting-started.k8s.drawio.svg)

## Prerequisites

### Tooling

The required tooling as described in the [Getting Started Guide - Prerequisites](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#prerequisites)

> [!NOTE]
> For contributing there is a dedicated page [CONTRIBUTING.md](../../CONTRIBUTING.md).

### AWS Authentication

Make sure to export your required [AWS Environment Variables](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html) to your CLI before getting started. For

  ```bash
  export AWS_ACCESS_KEY_ID=...
  export AWS_SECRET_ACCESS_KEY=...
  export AWS_SESSION_TOKEN=...
  ```

Alternatively

  ```bash
  export AWS_PROFILE=...
  ```

### Existing AWS Hosted Zone

These blueprints rely on an existing Hosted Zone in AWS Route53. If you don't have one, you can create one by following the [AWS Route53 documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-working-with.html).

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
| cjoc_url | URL of the CloudBees CI Operations Center for CloudBees CI Add-on. |
| eks_cluster_arn | EKS cluster ARN |
| export_kubeconfig | Export KUBECONFIG environment variable to access to access the K8s API. |
| vpc_arn | VPC ID |
<!-- END_TF_DOCS -->

## Deploy

First of all, customize your terraform values by copying `.auto.tfvars.example` to `.auto.tfvars`.

Initialize the root module and any associated configuration for providers and finally create the resources and deploy CloudBees CI to an EKS Cluster. Please refer to [Getting Started - Amazon EKS Blueprints for Terraform - Deploy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy)

For more detailed information, see the documentation for the [Terraform Core workflow](https://www.terraform.io/intro/core-workflow).

Once deployed has finished, it is possible to check the generated AWS resources via Resource Groups.

> [!TIP]
> These steps are automated in the [Makefile](../../Makefile) at the root of the project under the target `deploy`.

## Validate

Once the resources have been created, note that a kubeconfig file has been created inside the respective blueprint folder. Start defining the Environment Variable [KUBECONFIG](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#the-kubeconfig-environment-variable) to point to the generated file.

  ```sh
  eval $(terraform output --raw export_kubeconfig)
  ```

Once you get access to K8s API from your terminal, validate that:

- The CloudBees Operation Center Pod is running

  ```sh
  until kubectl get pod -n cbci cjoc-0; do sleep 2 && echo "Waiting for Pod to get ready"; done; echo "OC Pod is Ready"
  ```

- The Ingress Controller is ready and has assigned an `ADDRESS`

  ```sh
  until kubectl get ing -n cbci cjoc; do sleep 2 && echo "Waiting for Ingress to get ready"; done; echo "Ingress Ready"
  ```

- It is possible to access the CloudBees CI installation Wizard by copying the outcome of the below command in your browser.

  ```sh
  terraform output cjoc_url
  ```

Now that you’ve installed CloudBees CI and operations center, you’ll want to see your system in action. To do this, follow the steps explained in [CloudBees CI EKS Install Guide - Signing in to your CloudBees CI installation](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/installing-eks-using-helm#log-in).

  ```sh
  kubectl exec -n cbci -ti cjoc-0 -- cat /var/jenkins_home/secrets/initialAdminPassword
  ```

Finally, install the suggested plugins and create the first admin user.

> [!TIP]
> These steps are automated in the [Makefile](../../Makefile) at the root of the project under the target `validate`.

## Destroy

To teardown and remove the resources created in the blueprint, the typical steps of execution are as explained in [Getting Started - Amazon EKS Blueprints for Terraform - Destroy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy)

> [!NOTE]
> Storage Classes have assigned `reclaimPolicy` to `Delete`, and then storage volume is deleted when it is no longer required by the pod. Otherwise, it would require deleting `pvc` manually. See [CloudBees CI EKS Uninstall](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/eks-uninstall)).

> [!TIP]
> These steps are automated in the [Makefile](../../Makefile) at the root of the project under the target `destroy`.
