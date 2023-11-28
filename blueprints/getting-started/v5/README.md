# CloudBees CI Add-on getting started Blueprint v5

[Getting started](../README.md) for [v5](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/v5.0.0).

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