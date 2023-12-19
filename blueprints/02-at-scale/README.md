# CloudBees CI Add-on at scale Blueprint

Once you have familiarized yourself with the [Getting Started blueprint](../01-getting-started/README.md), this blueprint presents a more scalable architecture by adding the following **optional EKS Addons**:

- [Cluster Autoscaler](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/cluster-autoscaler/)
<!-- - [Node Termination Handler](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-node-termination-handler/) -->
- [EFS CSI Driver](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-efs-csi-driver/). CloudBees CI HA/HS requirement.
- [Metrics Server](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-efs-csi-driver/). CloudBees CI HA/HS requirement for Horizontal Pod Autoscaling.

Additionally, it uses [CloudBees Configuration as Code](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/casc-intro) for configuring the [Operation Center](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/) and [Controllers](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/).

## Prerequisites

Refer to the [Getting Started Blueprint - Prerequisites](../01-getting-started/README.md#prerequisites) section.

## Terraform Docs

<!-- BEGIN_TF_DOCS -->
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| domain_name | Desired domain name (e.g. example.com) used as suffix for CloudBees CI subdomains (e.g. cjoc.example.com). It requires to be mapped within an existing Route 53 Hosted Zone. | `string` | n/a | yes |
| temp_license | Temporary license details | `map(string)` | n/a | yes |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| acm_certificate_arn | ACM certificate ARN |
| cjoc_url | URL of the CloudBees CI Operations Center |
| eks_bp_addon_cbci_helm | Helm configuration for CloudBees CI Add-on. It is accesible only via state files. |
| eks_bp_addon_cbci_initial_admin_password | Operation Center Service Initial Admin Password for CloudBees CI Add-on. |
| eks_bp_addon_cbci_liveness_probe_ext | Operation Center Service External Liveness Probe for CloudBees CI Add-on. |
| eks_bp_addon_cbci_liveness_probe_int | Operation Center Service Internal Liveness Probe for CloudBees CI Add-on. |
| eks_bp_addon_cbci_namepace | Namespace for CloudBees CI Add-on. |
| eks_bp_addon_cbci_oc_ing | Operation Center Ingress for CloudBees CI Add-on. |
| eks_bp_addon_cbci_oc_pod | Operation Center Pod for CloudBees CI Add-on. |
| eks_cluster_arn | EKS cluster ARN |
| export_kubeconfig | Export KUBECONFIG environment variable to access the EKS cluster. |
| vpc_arn | VPC ID |
<!-- END_TF_DOCS -->

## Deploy

Refer to the [Getting Started Blueprint - Prerequisites](../01-getting-started/README.md#deploy) section.

## Validate

Refer to the [Getting Started Blueprint - Prerequisites](../01-getting-started/README.md#validate) section.

## Destroy

Refer to the [Getting Started Blueprint - Prerequisites](../01-getting-started/README.md#destroy) section.

## Architecture

![Architecture]()
