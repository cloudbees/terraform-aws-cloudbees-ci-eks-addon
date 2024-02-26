# Contributing

This document provides guidelines for contributing to the module.

## Reporting Bugs/Feature Requests

We welcome you to use the GitHub issue tracker to report bugs or suggest features.

When filing an issue, please check existing open, or recently closed, issues to make sure somebody else hasn't already reported the issue. Review also the upstream repositories:

- [aws-ia/terraform-aws-eks-blueprints](https://github.com/aws-ia/terraform-aws-eks-blueprints)
- [aws-ia/terraform-aws-eks-blueprints-addons](https://github.com/aws-ia/terraform-aws-eks-blueprints-addons/tree/main)

Please try to include as much information as you can. Details like these are incredibly useful:

- A reproducible test case or series of steps
- The version of our code being used
- Any modifications you've made relevant to the bug
- Anything unusual about your environment or deployment

## Contributing via Pull Requests

Contributions via pull requests are much appreciated. Before sending us a pull request, please ensure that:

1. You are working against the latest source on the _main_ branch.
2. You check existing open, and recently merged, pull requests to make sure someone else hasn't addressed the problem already.
3. You open an issue to discuss any significant work - we would hate for your time to be wasted.

To send us a pull request, please:

1. Fork the repository.
2. Modify the source; please focus on the specific change you are contributing. If you also reformat all the code, it will be hard for us to focus on your change.
3. **Ensure local tests pass**.
4. Commit to your fork using clear commit messages.
5. Send us a pull request against _dev_, answering any default questions in the pull request interface.
6. Pay attention to any automated CI failures reported in the pull request, and stay involved in the conversation.

GitHub provides additional document on [forking a repository](https://help.github.com/articles/fork-a-repo/) and
[creating a pull request](https://help.github.com/articles/creating-a-pull-request/).

## CI Pipeline

Validate your Pull Request changes inside the blueprint agent described in the [Dockerfile](.docker). It is the same agent used for the CI pipeline [agent.yaml](.cloudbees/workflows/agent.yaml).

> [!NOTE]
> The agent and dependencies can be automated using the [Makefile](Makefile) at the root of the project, under the target `dRun`. It is the same Makefile used in the CloudBees CI pipeline.

The [ci.yaml](.cloudbees/workflows/ci.yaml) blueprints are orchestrated into the [CloudBees platform](https://www.cloudbees.com/products/saas-platform) inside the [CloudBees Professional Services (PS) sub-organization](https://cloudbees.io/orgs/cloudbees~professional-services/components/94c50dcf-125e-4767-b9c5-58d6d669a1f6/runs).

Prerequisites:

- AWS user with permission to create resources in the target account (`AWS_TF_CBCI_EKS_AccessKeyID` and `AWS_TF_CBCI_EKS_SecretAccessKey`).
- AWS role to assume in the target account, including a trust relationship with the AWS user above.
- AWS Route 53 zone name, to create DNS records.

> [!IMPORTANT]
> At the moment, CloudBees Platform only supports push events. Therefore, Pull request are sent to the _dev_ branch for integration.

## Pre-commits: Linting, Formatting and Secrets Scanning

Many of the files in the repository can be lined or formatted to maintain a standard of quality. Additionally, secret leaks are watched via [gitleaks](https://github.com/zricethezav/gitleaks#pre-commit) and [git-secrets](https://github.com/awslabs/git-secrets).

When working with the repository for the first time, you must run `pre-commit`:

1. Run `pre-commit install`.
2. Run `pre-commit run --all-files`.

## Release Drafter

This repository uses [Release Drafter](https://github.com/release-drafter/release-drafter); you must label pull requests accordingly.
