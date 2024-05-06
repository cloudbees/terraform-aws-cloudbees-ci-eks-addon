# Contribute

This document provides guidelines for contributing to the CloudBees CI add-on for Amazon EKS blueprints.

## Design principles

It follows the same approach as the [Terraform AWS EKS Blueprints for Terraform Patterns](https://aws-ia.github.io/terraform-aws-eks-blueprints/).

## Report bugs and feature requests

CloudBees welcomes you to use the GitHub issue tracker to report bugs or suggest features.

When filing an issue:

1. Check existing open and recently closed [issues](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/issues) to ensure the issue has not already been reported.
2. Review the upstream repositories:
   - [aws-ia/terraform-aws-eks-blueprints](https://github.com/aws-ia/terraform-aws-eks-blueprints/issues)
   - [aws-ia/terraform-aws-eks-blueprints-addons](https://github.com/aws-ia/terraform-aws-eks-blueprints-addons/issues)
3. Try to include as much information as you can. Details like the following are incredibly useful:
   - A reproducible test case or series of steps
   - The version of code being used
   - Any modifications you have made relevant to the bug
   - Anything unusual about your environment or deployment

## Contribute via pull requests

Contributions via pull requests are appreciated. Before submitting a pull request, please ensure that you:

1. Are working against the latest source on the `main` branch.
2. Check existing open, and recently merged, pull requests to make sure someone else has not already addressed the problem.
3. Open an issue to discuss any significant work; we do not want your time to be wasted.

To submit a pull request:

1. Fork the repository.
2. Create feature branch extending from the `main` branch.
3. Modify the source and focus on the specific change you are contributing. If you reformat all the code, it is hard for reviewers to focus on your specific change.
4. **Ensure that local tests pass**.
5. Make commits to your fork using clear commit messages.
6. Submit a pull request against the `develop` branch and answer any default questions in the pull request interface.
7. Pay attention to any automated CI failures reported in the pull request, and stay involved in the conversation.

> [!IMPORTANT]
> If you make updates to CasC bundles, you must push the changes to a public repository/branch before running `terraform apply`. The default is `https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon.git/main`, which follows a monorepo approach where the CasC bundles and `blueprints` are stored in the same repository.

>[!TIP]
> GitHub provides additional documentation on [forking a repository](https://help.github.com/articles/fork-a-repo/) and [creating a pull request](https://help.github.com/articles/creating-a-pull-request/).

### Pre-commits: Linting, formatting and secrets scanning

Many of the files in the repository can be linted or formatted to maintain a standard of quality. Additionally, secret leaks are watched via [gitleaks](https://github.com/zricethezav/gitleaks#pre-commit) and [git-secrets](https://github.com/awslabs/git-secrets).

1. When working with the repository for the first time, you must install `pre-commit`. For more information, refer to [pre-commit installation](https://pre-commit.com/#installation).
2. Run `pre-commit run --all-files`. Run this command again if the automated checks fail when you create a pull request.

## Blueprint Terraform CI pipeline

Validate your pull request changes inside the blueprint agent described in the [Dockerfile](.docker/agent). It is the same agent used for the CI pipeline [bp-agent-ecr.yaml](.cloudbees/workflows/bp-agent-ecr.yaml).

> [!NOTE]
> The agent and dependencies can be automated using the [Makefile](Makefile) at the root of the project, under the target `bpAgent-dRun`. It is the same Makefile used in the CloudBees CI pipeline.

The [bp-tf-ci.yaml](.cloudbees/workflows/bp-tf-ci.yaml) blueprints are orchestrated into the [CloudBees platform](https://www.cloudbees.com/products/saas-platform) inside the [CloudBees Professional Services (PS) sub-organization](https://cloudbees.io/orgs/cloudbees~professional-services/components/94c50dcf-125e-4767-b9c5-58d6d669a1f6/runs).

### Prerequisites

- AWS user with permission to create resources in the target account (for example, `AWS_TF_CBCI_EKS_AccessKeyID` and `AWS_TF_CBCI_EKS_SecretAccessKey`).
- AWS role to assume in the target account, including a trust relationship with the AWS user above.
- AWS Route 53 zone name, to create DNS records.

> [!IMPORTANT]
> CloudBees Platform currently only supports push events. Therefore, pull requests are sent to the `develop` branch for integration.

## Release

CloudBees CI Terraform EKS Addon versions try to be in sync with the [CloudBees CI releases](https://docs.cloudbees.com/docs/release-notes/latest/cloudbees-ci/).

Before a new CloudBees CI Helm chart is released, new features for this addon and its companion blueprints are merged into the integration branch (`develop`). When a new version of the CloudBees CI Helm chart is released, the addon is updated to the new version following this process:

1. Test the update in the integration branch (`develop`).
   - Update the `version` field if CloudBees CI Terraform EKS Addon update needs to be updated to the new [version of the Helm chart](https://artifacthub.io/packages/helm/cloudbees/cloudbees-core/).
   - The field `source` in the `eks_blueprints_addon_cbci` in the blueprints folder must point to the local CloudBees CI Terraform EKS Addon root of the repository `source = "../../"` (not to the remote [terraform registry version](https://registry.terraform.io/modules/cloudbees/cloudbees-ci-eks-addon/aws/latest)).
   - Test the update locally

> [!TIP]
> Use the following targets from [Makefile](Makefile): `deploy` > `validate` > `destroy`.

2. Create a PR against the `main` branch. including the Helm chart update plus other updates available in the integration branch (`develop`). Ensure that the field `source` in the `eks_blueprints_addon_cbci` at blueprints is pointing to the remote [terraform registry version](https://registry.terraform.io/modules/cloudbees/cloudbees-ci-eks-addon/aws/latest) and `version >= "x.x.x"`.
3. Once the pull request is merged, verify that the `main` branch successfully passes the [Terraform CI build](#blueprint-terraform-ci-pipeline).
4. Create a [new release](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/releases). The release version semantics follow the Helm chart convention.

> [!IMPORTANT]
> This project uses a mono-repository approach where the CasC bundles and `blueprints` are stored in the same repository.  In the `main` branch CasC bundle SCM configuration should point to the `main` branch.

This project uses [Release Drafter](https://github.com/release-drafter/release-drafter); pull request labels should be set accordingly.

Kubernetes' environment versions are managed centrally in the [blueprints/.k8.env](blueprints/.k8s.env) file.
