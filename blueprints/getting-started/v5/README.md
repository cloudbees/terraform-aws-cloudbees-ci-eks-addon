# HashiCorp Consul Add-on for AWS EKS

> Get started with this add-on by reviewing the following example using [AWS EKS Blueprint v5](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/main).

## Overview

The code in this directory showcases an easy way to get started with the HashiCorp Consul Add-on for AWS EKS.

* [main.tf](./main.tf) contains the AWS and Kubernetes resources needed to use this add-on.
* [outputs.tf](./outputs.tf) defines outputs that make interacting with `kubectl` easier
* [providers.tf](./providers.tf) defines the required Terraform (core) and Terraform provider versions
* [variables.tf](./variables.tf) defines the variables needed to use this add-on.

## Usage

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

Initialize the root module and any associated configuration for providers, review the resources that will be created and finally create the resources and deploy CloudBees CI to an EKS Cluster. For more detailed information, see the documentation for the [Terraform Core workflow](https://www.terraform.io/intro/core-workflow).

  ```sh
  terraform init -upgrade
  terraform plan
  terraform apply
  ```

Once the resources have been created, import the credentials to the `$home/.kube/config` by running in your terminal the outcome of the following command:

  ```sh
  eval $(terraform output --raw configure_kubectl)
  ```

Once you validate that:

1. The CloudBees Operation Center Pod is running

  ```sh
  until kubectl get pod -n cloudbees-ci cjoc-0; do sleep 2 && echo "Waiting for Pod to get ready"; done; echo "OC Pod is Ready"
  ```

2. The Ingress Controller is ready and has assigned an `ADDRESS`

  ```sh
  until kubectl get ing -n cloudbees-ci cjoc; do sleep 2 && echo "Waiting for Ingress to get ready"; done; echo "Ingress Ready"
  ```

Get the URL for the CloudBees CI Console that you need to open in your browser:

  ```sh
  terraform output cjoc_url
  ```

Then, the CloudBees CI installation Wizard will be displayed asking for initial password that can obtained by:

  ```sh
  kubectl exec -n cloudbees-ci -ti cjoc-0 -- cat /var/jenkins_home/secrets/initialAdminPassword
 ```

Finally, install the suggested plugins and create the first admin user.

<!-- BEGIN_TF_DOCS -->
### Inputs

No inputs.

### Outputs

No outputs.
<!-- END_TF_DOCS -->