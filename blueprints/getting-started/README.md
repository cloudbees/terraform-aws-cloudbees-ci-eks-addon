# CloudBees CI Add-on getting started Blueprint

Get started with the CloudBees CI add-on by reviewing this example which deploys the minimum set of resources to install [CloudBees CI on EKS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/) following its [prerequisites](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/installing-eks-using-helm#_prerequisites):

- AWS Certificate Manager
- [AWS Load Balancer Controller](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-load-balancer-controller/)
- [External DNS](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/external-dns/)

The code in this directory demonstrates its compatibility with [AWS EKS Blueprint v4](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/v4.32.1) and [AWS EKS Blueprint v5](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/v5.0.0) (Additional info on [v4 to v5 migration guide](https://aws-ia.github.io/terraform-aws-eks-blueprints/v4-to-v5/motivation/)).

- [v4](v4/README.md)
- [v5](v5/README.md)

## Prerequisites

### Tooling

The required tooling as described in the [Getting Started Guide - Prerequisites](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#prerequisites)

> **_NOTE:_** For contributing there is a dedicated page [CONTRIBUTING.md](../../CONTRIBUTING.md).

### AWS Authentication

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

### Existing AWS Hosted Zone

These blueprints rely on an existing Hosted Zone in AWS Route53. If you don't have one, you can create one by following the [AWS Route53 documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-working-with.html).

## Deploy

First of all, customize your variables by copying `.auto.tfvars.example` to `.auto.tfvars`.

Initialize the root module and any associated configuration for providers and finally create the resources and deploy CloudBees CI to an EKS Cluster. Please refer to [Getting Started - Amazon EKS Blueprints for Terraform - Deploy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy)

In case, it is required to review the resources before applying the changes, remove the flag `-auto-approve` from the commands.

For more detailed information, see the documentation for the [Terraform Core workflow](https://www.terraform.io/intro/core-workflow).

> **_NOTE:_** These steps are automated in the [Makefile](../../Makefile) at the root of the project under the target `tfDeploy`.

## Validate

Once the resources have been created, start by importing the credentials to the `$home/.kube/config` by running in your terminal the outcome of the following command:

  ```sh
  eval $(terraform output --raw configure_kubectl)
  ```

Once you get access to K8s API from your terminal, validate that:

- The CloudBees Operation Center Pod is running

  ```sh
  until kubectl get pod -n cloudbees-ci cjoc-0; do sleep 2 && echo "Waiting for Pod to get ready"; done; echo "OC Pod is Ready"
  ```

- The Ingress Controller is ready and has assigned an `ADDRESS`

  ```sh
  until kubectl get ing -n cloudbees-ci cjoc; do sleep 2 && echo "Waiting for Ingress to get ready"; done; echo "Ingress Ready"
  ```

- It is possible to access the CloudBees CI installation Wizard by copying the outcome of the below command in your browser:

  ```sh
  terraform output cjoc_url
  ```

Now that you’ve installed CloudBees CI and operations center, you’ll want to see your system in action. To do this, follow the steps explained in [CloudBees CI EKS Install Guide - Signing in to your CloudBees CI installation](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/installing-eks-using-helm#log-in).

  ```sh
  kubectl exec -n cloudbees-ci -ti cjoc-0 -- cat /var/jenkins_home/secrets/initialAdminPassword
  ```

Finally, install the suggested plugins and create the first admin user.

> **_NOTE:_** These steps are automated in the [Makefile](../../Makefile) at the root of the project under the target `validate`.

## Destroy

As the PVCs are not deleted by default, it is required to delete them manually as you can check on the [CloudBees CI EKS Uninstall](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/eks-uninstall).

  ```sh
  kubectl delete --all pvc --grace-period=0 --force --namespace cloudbees-ci
  ```

To teardown and remove the resources created in the blueprint, the typical steps of execution are as explained in [Getting Started - Amazon EKS Blueprints for Terraform - Destroy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy)

> **_NOTE:_** These steps are automated in the [Makefile](../../Makefile) at the root of the project under the target `tfDestroy`.

## Architecture

![Architecture](../diagrams/getting-started.drawio.png)
