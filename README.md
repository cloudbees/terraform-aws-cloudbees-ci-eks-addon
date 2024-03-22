# CloudBees CI add-on for Amazon EKS blueprints

<p align="center">
  <a href="https://www.cloudbees.com/capabilities/continuous-integration"><img alt="CloudBees CI add-on for Amazon EKS blueprints" src="https://images.ctfassets.net/vtn4rfaw6n2j/7FKeUjwsXI1d2JPUIvSMZJ/be286872ace9ca3b6b66a64adbb3c16a/cb-tag-sm.svg"/></a>
  <p align="center">Deploy CloudBees CI to Amazon Web Services (AWS) Elastic Kubernetes Service (EKS) clusters</p>

---

[![GitHub Latest Release)](https://img.shields.io/github/v/release/cloudbees/terraform-aws-cloudbees-ci-eks-addon?logo=github)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/releases)
[![GitHub Issues](https://img.shields.io/github/issues/cloudbees/terraform-aws-cloudbees-ci-eks-addon?logo=github)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/issues)
[![Code Quality: Terraform](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/terraform.yml/badge.svg?event=pull_request)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/terraform.yml)
[![Code Quality: Super-Linter](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/superlinter.yml/badge.svg?event=pull_request)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/superlinter.yml)
[![Documentation: MD Links Checker](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/md-link-checker.yml/badge.svg?event=pull_request)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/md-link-checker.yml)
[![Documentation: terraform-docs](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/terraform-docs.yml/badge.svg?event=pull_request)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/terraform-docs.yml)
[![gitleaks badge](https://img.shields.io/badge/protected%20by-gitleaks-blue)](https://github.com/zricethezav/gitleaks#pre-commit)
[![gitsecrets](https://img.shields.io/badge/protected%20by-gitsecrets-blue)](https://github.com/awslabs/git-secrets)

## Motivation

The CloudBees CI [AWS partner add-on](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/aws-partner-addons/) streamlines the adoption and experimentation of CloudBees CI enterprise features by:

- Encapsulating the deployment of [CloudBees CI on modern platforms in AWS EKS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/installing-eks-using-helm#_configuring_your_environment) into a Terraform module.
- Providing a series of [blueprints](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/tree/main/blueprints) that implement the CloudBees CI add-on module for use with [Amazon EKS blueprints for Terraform](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/), which are aligned with the [EKS Best Practices Guides](https://aws.github.io/aws-eks-best-practices/).

## Usage

Implementation examples are included in the [blueprints](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/tree/main/blueprints) folder, however this is the simplest example of usage:

```terraform
module "eks_blueprints_addon_cbci" {
  source  = "cloudbees/cloudbees-ci-eks-addon/aws"
  version = "~> 3.16720.0"
  
  hosted_zone    = "example.domain.com"
  cert_arn     = "arn:aws:acm:us-east-1:0000000:certificate/0000000-aaaa-bbb-ccc-thisIsAnExample"
  trial_license = {
    first_name  = "Foo"
    last_name  = "Bar"
    email = "foo.bar@acme.com"
    company = "Acme Inc."
  }

}
```

By default, it uses a minimum required configuration described in the Helm chart [values.yaml](values.yml) file. If you need to override any default settings with the chart, you can do so by passing the `helm_config` variable.

## Prerequisites

### Tools

The blueprint `deploy` and `destroy` phases use the same requirements provided in the [AWS EKS Blueprints for Terraform - Prerequisites](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#prerequisites). However, the blueprint `validate` phase may require additional tooling, such as `jq` and `velero`.

> [!NOTE]
> There is a companion [Dockerfile](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/tree/main/.docker) to run the blueprints in a containerized development environment, ensuring all dependencies are met. It can be built locally using the [Makefile](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/blob/main/Makefile) target `make bpAgent-dRun`.

### AWS authentication

Before getting started, you must export your required [AWS environment variables](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html) to your CLI (for example, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_PROFILE`).

### Existing AWS hosted zone

These blueprints rely on an existing hosted zone in AWS Route 53. If you do not have a hosted zone, you can create one by following the [AWS Route 53 documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-working-with.html).

## Data Storage Options

The two main components of CloudBees CI - the operations center and managed controllers - use a file system to persist data. By default, data is stored in the [$JENKINS_HOME](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/jenkins-home) folder, but can be configured to be stored in Amazon Elastic Block Store (Amazon EBS) or Amazon Elastic File System (Amazon EFS):

- Amazon EBS volumes are scoped to a particular availability zone to offer high-speed, low-latency access to the Amazon Elastic Compute Cloud (Amazon EC2) instances they are connected to. If an availability zone fails, an Amazon EBS volume becomes inaccessible due to file corruption, or there is a service outage, the data on these volumes becomes inaccessible. The operations center and managed controller pods require this persistent data and have no mechanism to replicate the data, so CloudBees recommends frequent backups for Amazon EBS.
- Amazon EFS file systems are scoped to an AWS region and can be accessed from any availability zone in the region that the file system was created in. Using Amazon EFS as a storage class for the operations center and managed controllers allows pods to be rescheduled successfully onto healthy nodes in the event of an availability zone outage. Amazon EFS is more expensive than Amazon EBS, but provides greater fault tolerance.

> [!IMPORTANT]  
> - CloudBees CI High Availability (HA) (active-active) requires Amazon EFS. For more information, refer to [CloudBees CI EKS storage requirements](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/eks-pre-install-requirements-helm#_storage_requirements).
> - For more information on pricing, refer to [Amazon EBS pricing](https://aws.amazon.com/ebs/pricing/) and [Amazon EFS pricing](https://aws.amazon.com/efs/pricing/).

## CloudBees CI trial license

This module runs with a [trial license for CloudBees CI](https://docs.cloudbees.com/docs/cloudbees-ci-migration/latest/trial-guide/).
Once the trial has expired, refer to [CloudBees CI license expiration FAQ](https://docs.cloudbees.com/docs/general-kb/latest/faqs/jenkins-enterprise-license-expiration-faq) to determine your next steps.

## Compatibility

The CloudBees CI add-on uses `helms release` for its resources definition, making it compatible with [AWS EKS Blueprint v4](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/v4.32.1) and [AWS EKS Blueprint v5](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/v5.0.0). For more information, refer to [Amazon EKS Blueprints for Terraform: v4 to v5 migration](https://aws-ia.github.io/terraform-aws-eks-blueprints/v4-to-v5/motivation/).

## Terraform documentation

<!-- BEGIN_TF_DOCS -->
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cert_arn | AWS Certificate Manager (ACM) certificate for Amazon Resource Names (ARN). | `string` | n/a | yes |
| hosted_zone | Amazon Route 53 hosted zone name. | `string` | n/a | yes |
| trial_license | CloudBees CI trial license details for evaluation. | `map(string)` | n/a | yes |
| create_k8s_secrets | Create the Kubernetes secret cbci-secrets. It can be consumed by CasC. | `bool` | `false` | no |
| helm_config | CloudBees CI Helm chart configuration. | `any` | <pre>{<br>  "values": [<br>    ""<br>  ]<br>}</pre> | no |
| k8s_secrets_file | Secrets file .yml path containing the secrets names:values for cbci-secrets. | `string` | `"secrets-values.yml"` | no |
| prometheus_target | Create Service Monitor to discover CloudBees CI Apps Prometheus Target dinamically. It is designed to be enabled with AWS EKS Terraform Addon Kube Prometheus Stack. | `bool` | `false` | no |

### Outputs

| Name | Description |
|------|-------------|
| cbci_domain_name | Amazon Route 53 domain name to host CloudBees CI services. |
| cbci_liveness_probe_ext | Operations center service external liveness probe for the CloudBees CI add-on. |
| cbci_liveness_probe_int | Operations center service internal liveness probe for the CloudBees CI add-on. |
| cbci_namespace | Namespace for the CloudBees CI add-on. |
| cbci_oc_ing | Operations center Ingress for the CloudBees CI add-on. |
| cbci_oc_pod | Operations center pod for the CloudBees CI add-on. |
| cbci_oc_url | Operations center URL for the CloudBees CI add-on using a subdomain and certificates. |
| cbci_secrets | Kubernetes secrets name for CloudBees CI. Optional. |
| merged_helm_config | (merged) Helm configuration for CloudBees CI. |
<!-- END_TF_DOCS -->

## Additional resources

- [CloudBees CI documentation](https://docs.cloudbees.com/docs/cloudbees-ci/latest/)
- [CloudBees CI release notes](https://docs.cloudbees.com/docs/release-notes/latest/cloudbees-ci/)
- [Architecture for CloudBees CI on modern cloud platforms](https://docs.cloudbees.com/docs/cloudbees-ci/latest/architecture/ci-cloud)
- [Amazon EKS Blueprints Addons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/)
- [Amazon EKS Blueprints for Terraform](https://aws-ia.github.io/terraform-aws-eks-blueprints/)
- [Containers: Bootstrapping clusters with EKS Blueprints](https://aws.amazon.com/blogs/containers/bootstrapping-clusters-with-eks-blueprints/)
- [EKS Workshop](https://www.eksworkshop.com/)
