# CloudBees CI Add-on for AWS EKS

![GitHub Latest Release)](https://img.shields.io/github/v/release/cloudbees/terraform-aws-cloudbees-ci-eks-addon?logo=github) ![GitHub Issues](https://img.shields.io/github/issues/cloudbees/terraform-aws-cloudbees-ci-eks-addon?logo=github) [![Code Quality: Terraform](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/terraform.yml/badge.svg?event=pull_request)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/terraform.yml) [![Code Quality: Super-Linter](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/superlinter.yml/badge.svg?event=pull_request)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/superlinter.yml) [![Documentation: MD Links Checker](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/md-link-checker.yml/badge.svg?event=pull_request)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/md-link-checker.yml) [![Documentation: terraform-docs](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/terraform-docs.yml/badge.svg?event=pull_request)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/terraform-docs.yml) [![gitleaks badge](https://img.shields.io/badge/protected%20by-gitleaks-blue)](https://github.com/zricethezav/gitleaks#pre-commit) [![gitsecrets](https://img.shields.io/badge/protected%20by-gitsecrets-blue)](https://github.com/awslabs/git-secrets)

> Deploy CloudBees CI to AWS EKS Clusters with this add-on.

## Usage

By default, it uses a minimum required configuration described in [values.yml](values.yml).

If you would like to override any defaults with the chart, you can do so by passing the `helm_config` variable.

## Data Storage Options

The two main components of CloudBees CI, Operations Center and Managed Controllers, use a file system to persist data. Data is stored in a folder called [Jenkins Home](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/jenkins-home) that can be configured to be stored in Amazon EBS or EFS:

- Amazon EBS volumes are scoped to a particular Availability Zone to offer high-speed, low-latency access to the EC2 instances they are connected to. If an Availability Zone fails, an EBS volume becomes inaccessible due to file corruption, or there is a service outage, the data on these volumes will become inaccessible. Operations Center and Managed Controller pods require this persistent data and have no mechanism to replicate the data, so we recommend frequent backups using [Velero](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/velero-dr) for Amazon EBS.
- Amazon EFS file systems are scoped to an AWS Region and can be accessed from any Availability Zone in the Region the file system was created in. Using Amazon EFS as a storage class for the Operations Center and Managed Controller allows pods to be rescheduled successfully onto healthy nodes in the event of an Availability Zone outage. Amazon EFS file systems may increase the cost of the deployment compared to the Amazon EBS option, but provide greater fault tolerance.

> [!IMPORTANT]  
> CloudBees HA (active-active) requires Amazon EFS. See [CloudBees CI EKS Storage Requirements](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/eks-pre-install-requirements-helm#_storage_requirements).

> [!NOTE]
> For more information on pricing, see the [Amazon EBS pricing page](https://aws.amazon.com/ebs/pricing/) and the [Amazon EFS pricing page](https://aws.amazon.com/efs/pricing/).

## Motivation

Easing adoption of CloudBees CI by:

- Providing a CloudBees CI terraform module to deploy [CloudBees CI in EKS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/) via Helm.
- Provide a series of blueprints (examples of implementation) using the CloudBees CI Add-on module.
- Using [AWS Terraform EKS Addons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/) as the single point of truth for third-party EKS Addons. Note that some of the addons are required and others are optional.

> [!NOTE]
> For a better understading of the blueprints' scope, please read the section [Consumption](https://aws-ia.github.io/terraform-aws-eks-blueprints/#consumption) and [Terraform Caveats](https://aws-ia.github.io/terraform-aws-eks-blueprints/#terraform-caveats) in AWS the EKS blueprints documentation.

## CloudBees License

This module runs with a [Trial License for CloudBees CI](https://docs.cloudbees.com/docs/cloudbees-ci-migration/latest/trial-guide/).

Check out [CloudBees CI License Expiration FAQ](https://docs.cloudbees.com/docs/general-kb/latest/faqs/jenkins-enterprise-license-expiration-faq) once the trial has expired to define our next steps.

## Compatibility

CloudBees CI Add-on uses for its resources definition `helms release` which makes it compatible [AWS EKS Blueprint v4](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/v4.32.1) and [AWS EKS Blueprint v5](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/v5.0.0) (Additional info at [v4 to v5 migration guide](https://aws-ia.github.io/terraform-aws-eks-blueprints/v4-to-v5/motivation/)).

## Terraform Docs

<!-- BEGIN_TF_DOCS -->
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cert_arn | Certificate ARN from AWS ACM | `string` | n/a | yes |
| hostname | Route53 Hosted zone name | `string` | n/a | yes |
| temp_license | Temporary license details | `map(string)` | n/a | yes |
| helm_config | CloudBees CI Helm chart configuration | `any` | <pre>{<br>  "values": [<br>    ""<br>  ]<br>}</pre> | no |

### Outputs

| Name | Description |
|------|-------------|
| cbci_liveness_probe_ext | Operation Center Service External Liveness Probe for CloudBees CI Add-on. |
| cbci_liveness_probe_int | Operation Center Service Internal Liveness Probe for CloudBees CI Add-on. |
| cbci_namespace | Namespace for CloudBees CI Addon. |
| cbci_oc_ing | Operation Center Ingress for CloudBees CI Add-on. |
| cbci_oc_pod | Operation Center Pod for CloudBees CI Add-on. |
| cbci_oc_url | Operation Center URL for CloudBees CI Add-on using Subdomain and Certificates. |
| merged_helm_config | (merged) Helm Config for CloudBees CI |
<!-- END_TF_DOCS -->

## Communications

Cloudbees' slack channel [#cbci-eks-blueprints](https://cloudbees.slack.com/archives/C05NACAEM5H)

## References

- [Amazon EKS Blueprints for Terraform](https://aws-ia.github.io/terraform-aws-eks-blueprints/)
- [Amazon EKS Blueprints Addons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/)
- [Bootstrapping clusters with EKS Blueprints | Containers](https://aws.amazon.com/blogs/containers/bootstrapping-clusters-with-eks-blueprints/)
- [CloudBees CI Docs](https://docs.cloudbees.com/docs/cloudbees-ci/latest/)
- [CloudBees CI release notes](https://docs.cloudbees.com/docs/release-notes/latest/cloudbees-ci/)
- [Architecture for CloudBees CI on modern cloud platforms](https://docs.cloudbees.com/docs/cloudbees-ci/latest/architecture/ci-cloud)
