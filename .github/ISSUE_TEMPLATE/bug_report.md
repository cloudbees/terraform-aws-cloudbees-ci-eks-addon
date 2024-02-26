---
name: Bug report
about: Create a report to help us improve
---

## Description

Please provide a clear and concise description of the issue you are encountering, and a reproduction of your configuration. The reproduction MUST be executable by running `terraform init && terraform apply` without any further changes.

If your request is for a new feature, please use the `Feature request` template.

- [ ] I have searched the open/closed issues in this repository and my issue is not listed.
- [ ] I have checked that local tests are passing.
- [ ] If the issue is related to an AWS EKS add-on, I have searched the open/closed issues in the upstream [aws-ia/terraform-aws-eks-blueprints](https://github.com/aws-ia/terraform-aws-eks-blueprints) and my issue is not listed.
- [ ] If the issue is related to an AWS EKS add-on, I have checked that [upstream tests for the eks terraform blueprints add-on](https://github.com/aws-ia/terraform-aws-eks-blueprints-addons/tree/main/tests/complete) are passing.

## ⚠️ Note

Before you submit an issue, please perform the following first:

1. Remove the local `.terraform` directory (! ONLY if state is stored remotely, which hopefully you are following that best practice!): `rm -rf .terraform/`
2. Re-initialize the project root to pull down modules: `terraform init`
3. Re-attempt your terraform plan or apply and check if the issue still persists

## Versions

- Module version [Required]:

- Terraform version:
<!-- Execute terraform -version -->
- Provider version(s):
<!-- Execute: terraform providers -version -->

## Reproduction Code [Required]

<!-- REQUIRED -->

Steps to reproduce the behavior:

<!-- Are you using workspaces? -->
<!-- Have you cleared the local cache (see Notice section above)? -->
<!-- List steps in order that led up to the issue you encountered -->

## Expected behavior

<!-- A clear and concise description of what you expected to happen -->

## Actual behavior

<!-- A clear and concise description of what actually happened -->

### Terminal Output Screenshot(s)

<!-- Optional but helpful -->

## Additional context

<!-- Add any other context about the problem here -->
