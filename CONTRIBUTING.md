# Contributing

This document provides guidelines for contributing to the module.

## Dependencies

Validate your changes inside the blueprint agent described in the [Dockerfile](.docker).

> [!NOTE]
> The agent and dependecies can be automated via [Makefile](Makefile) at the root of the project under the target `dRun`. It is the same one used in the CI pipeline.

## Pre-commits: Linting, Formatting and Secrets Scanning

Many of the files in the repository can be lined or formatted to maintain a standard of quality.

Additionally, secret leaks are watched via gitleaks and git-secrets.

When working with the repository for the first time run pre-commit

Run `pre-commit install`
Run `pre-commit run --all-files`

## CI

Blueprints [CI](.cloudbees/workflows/ci.yaml) are orchestrated into [CloudBees platform](https://www.cloudbees.com/products/saas-platform) inside CloudBees Inc, PS Organization sub-organization (Runs [link](https://cloudbees.io/orgs/cloudbees~professional-services/components/94c50dcf-125e-4767-b9c5-58d6d669a1f6/runs))

Pre-requisites:

- AWS User with permission to create resources in the target account (`AWS_TF_CBCI_EKS_AccessKeyID` and `AWS_TF_CBCI_EKS_SecretAccessKey`).
- AWS Role to assume in the target account, including a trust relationship with the user above.
- AWS Route 53 Zone Name to create DNS records.

## Release Drafter

This repository uses [Release Drafter](https://github.com/release-drafter/release-drafter) do not forget to label Pull Request accordingly.
