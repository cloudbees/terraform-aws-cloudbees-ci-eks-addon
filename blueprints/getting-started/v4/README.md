# CloudBees CI Add-on getting started Blueprint v4

[Getting started](../README.md) for [v4](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/v4.32.1).

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
| configure_kubectl | Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig |
| eks_blueprints_addon_cbci_helm | Helm configuration for CloudBees CI Add-on. It is accesible only via state files. |
| eks_blueprints_addon_cbci_namepace | Namespace for CloudBees CI Add-on. |
| eks_cluster_arn | EKS cluster ARN |
| vpc_arn | VPC ID |
<!-- END_TF_DOCS -->