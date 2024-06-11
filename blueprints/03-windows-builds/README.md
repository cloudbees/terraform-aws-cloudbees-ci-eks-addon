# CloudBees CI blueprint add-on: Get started



## Architecture


### Kubernetes cluster


## Terrafor documentation

<!-- BEGIN_TF_DOCS -->
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| hosted_zone | Amazon Route 53 hosted zone. CloudBees CI applications are configured to use subdomains in this hosted zone. | `string` | n/a | yes |
| trial_license | CloudBees CI trial license details for evaluation. | `map(string)` | n/a | yes |
| suffix | Unique suffix to assign to all resources. | `string` | `""` | no |
| tags | Tags to apply to resources. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| acm_certificate_arn | AWS Certificate Manager (ACM) certificate for Amazon Resource Names (ARN). |
| cbci_helm | Helm configuration for the CloudBees CI add-on. It is accessible via state files only. |
| cbci_initial_admin_password | Operations center service initial admin password for the CloudBees CI add-on. |
| cbci_liveness_probe_ext | Operations center service external liveness probe for the CloudBees CI add-on. |
| cbci_liveness_probe_int | Operations center service internal liveness probe for the CloudBees CI add-on. |
| cbci_namespace | Namespace for the CloudBees CI add-on. |
| cbci_oc_ing | Operations center Ingress for the CloudBees CI add-on. |
| cbci_oc_pod | Operations center pod for the CloudBees CI add-on. |
| cbci_oc_url | URL of the CloudBees CI operations center for the CloudBees CI add-on. |
| eks_cluster_arn | Amazon EKS cluster ARN. |
| kubeconfig_add | Add kubeconfig to your local configuration to access the Kubernetes API. |
| kubeconfig_export | Export the KUBECONFIG environment variable to access the Kubernetes API. |
| vpc_arn | VPC ID. |
<!-- END_TF_DOCS -->

## Deploy


## Validate

Once the blueprint has been deployed, you can validate it.

### Kubeconfig

Once the resources have been created, a `kubeconfig` file is created in the [/k8s](k8s) folder. Issue the following command to define the [KUBECONFIG](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#the-kubeconfig-environment-variable) environment variable to point to the newly generated file:

```sh
  eval $(terraform output --raw kubeconfig_export)
```

If the command is successful, no output is returned.

### CloudBees CI

Once you can access the Kubernetes API from your terminal, complete the following steps.

Take the example from the Dropdown box menu:

```yaml
podTemplate(yaml: '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:windowsservercore-1809
  - name: shell
    image: mcr.microsoft.com/powershell:preview-windowsservercore-1809
    command:
    - powershell
    args:
    - Start-Sleep
    - 999999
  nodeSelector:
    kubernetes.io/os: windows
''') {
    node(POD_LABEL) {
        container('shell') {
            powershell 'Get-ChildItem Env: | Sort Name'
            powershell 'Start-Sleep -Seconds 30'
        }
    }
}
```

Observations:

- The first time it runs the build, the pod will take a while to be in `RUNNING STATE` because it needs to download the images (it is shown as `waiting`). Subsequent runs will be faster. (E.g. K8s events show no errors).
- Apart from the agent node itself, no other nodes are running in the Windows Node Group. (Initially, I thought that `kube-proxy` and `vpc-cni` were required to run in Windows Nodes as Daemonset but they are not).

```sh
$> kubectl get nodes -o wide
NAME                          STATUS   ROLES    AGE   VERSION               INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION                   CONTAINER-RUNTIME
ip-10-0-48-153.ec2.internal   Ready    <none>   35m   v1.28.8-eks-ae9a62a   10.0.48.153   <none>        Windows Server 2019 Datacenter   10.0.17763.5820                  containerd://1.6.28
ip-10-0-48-172.ec2.internal   Ready    <none>   40m   v1.28.8-eks-ae9a62a   10.0.48.172   <none>        Amazon Linux 2023.4.20240528     6.1.91-99.172.amzn2023.aarch64   containerd://1.7.11
ip-10-0-49-244.ec2.internal   Ready    <none>   40m   v1.28.8-eks-ae9a62a   10.0.49.244   <none>        Amazon Linux 2023.4.20240528     6.1.91-99.172.amzn2023.aarch64   containerd://1.7.11
$> kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=ip-10-0-48-153.ec2.internal
NAMESPACE   NAME                       READY   STATUS    RESTARTS   AGE   IP           NODE                          NOMINATED NODE   READINESS GATES
cbci        test-5-wqkqf-h2l8n-jnncp   2/2     Running   0          19s   10.0.48.72   ip-10-0-48-153.ec2.internal   <none>           <none>

```

Addon troubleshooting:

```sh
aws eks describe-addon --cluster-name cbci-bp01-windows-eks --region us-east-1 --addon-name kube-proxy --output yaml

addon:
  addonArn: arn:aws:eks:us-east-1:324005994172:addon/cbci-bp01-windows-eks/kube-proxy/82c800a2-cc53-8f27-5f10-06a828b0c38d
  addonName: kube-proxy
  addonVersion: v1.28.8-eksbuild.5
  clusterName: cbci-bp01-windows-eks
  createdAt: '2024-06-10T10:30:57.443000+02:00'
  health:
    issues: []
  modifiedAt: '2024-06-10T10:31:05.399000+02:00'
  status: ACTIVE
  tags:
    cb-owner: professional-services
    cb-purpose: demo
    cb-user: crodriguezlopez
    tf-blueprint: cbci-bp01-windows
    tf-repository: github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon

$> aws eks describe-addon-configuration --addon-name kube-proxy --addon-version v1.28.8-eksbuild.5 --profile infra-admin --region us-east-1 --output yaml

addonName: kube-proxy
addonVersion: v1.28.8-eksbuild.5
configurationSchema: '{"$ref":"#/definitions/KubeProxy","$schema":"http://json-schema.org/draft-06/schema#","definitions":{"Ipvs":{"additionalProperties":false,"properties":{"scheduler":{"type":"string"}},"title":"Ipvs","type":"object"},"KubeProxy":{"additionalProperties":false,"properties":{"ipvs":{"$ref":"#/definitions/Ipvs"},"mode":{"enum":["iptables","ipvs"],"type":"string"},"podAnnotations":{"properties":{},"title":"The podAnnotations Schema","type":"object"},"podLabels":{"properties":{},"title":"The podLabels Schema","type":"object"},"resources":{"$ref":"#/definitions/Resources"}},"title":"KubeProxy","type":"object"},"Limits":{"additionalProperties":false,"properties":{"cpu":{"type":"string"},"memory":{"type":"string"}},"title":"Limits","type":"object"},"Resources":{"additionalProperties":false,"properties":{"limits":{"$ref":"#/definitions/Limits"},"requests":{"$ref":"#/definitions/Limits"}},"title":"Resources","type":"object"}}}'
```

```sh
$> aws eks describe-addon --cluster-name cbci-bp01-windows-eks --region us-east-1 --addon-name coredns --output yaml
addon:
  addonArn: arn:aws:eks:us-east-1:324005994172:addon/cbci-bp01-windows-eks/coredns/5ac800a2-cc56-2a85-88e3-a946d66452b2
  addonName: coredns
  addonVersion: v1.10.1-eksbuild.11
  clusterName: cbci-bp01-windows-eks
  configurationValues: '{"tolerations":[{"effect":"NoSchedule","key":"os","operator":"Equal","value":"windows"}]}'
  createdAt: '2024-06-10T10:30:56.990000+02:00'
  health:
    issues: []
  modifiedAt: '2024-06-10T11:23:54.633000+02:00'
  status: ACTIVE
  tags:
    cb-owner: professional-services
    cb-purpose: demo
    cb-user: crodriguezlopez
    tf-blueprint: cbci-bp01-windows
    tf-repository: github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon

$> aws eks describe-addon-configuration --addon-name coredns --addon-version v1.10.1-eksbuild.11 --profile infra-admin --region us-east-1 --output yaml

addonName: coredns
addonVersion: v1.10.1-eksbuild.11
configurationSchema: '{"$ref":"#/definitions/Coredns","$schema":"http://json-schema.org/draft-06/schema#","definitions":{"Coredns":{"additionalProperties":false,"properties":{"affinity":{"default":{"affinity":{"nodeAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"kubernetes.io/os","operator":"In","values":["linux"]},{"key":"kubernetes.io/arch","operator":"In","values":["amd64","arm64"]}]}]}},"podAntiAffinity":{"preferredDuringSchedulingIgnoredDuringExecution":[{"podAffinityTerm":{"labelSelector":{"matchExpressions":[{"key":"k8s-app","operator":"In","values":["kube-dns"]}]},"topologyKey":"kubernetes.io/hostname"},"weight":100}]}}},"description":"Affinity
  of the coredns pods","type":["object","null"]},"autoScaling":{"additionalProperties":false,"description":"autoScaling
  configurations","properties":{"enabled":{"default":false,"description":"the option
  to enable eks managed autoscaling for coredns","type":"boolean"},"maxReplicas":{"description":"the
  max value that autoscaler can scale up the coredns replicas to","maximum":1000,"minimum":2,"type":"integer"},"minReplicas":{"default":2,"description":"the
  min value that autoscaler can scale down the coredns replicas to","maximum":1000,"minimum":2,"type":"integer"}},"required":["enabled"],"type":"object"},"computeType":{"type":"string"},"corefile":{"description":"Entire
  corefile contents to use with installation","type":"string"},"nodeSelector":{"additionalProperties":{"type":"string"},"type":"object"},"podAnnotations":{"properties":{},"title":"The
  podAnnotations Schema","type":"object"},"podDisruptionBudget":{"description":"podDisruptionBudget
  configurations","properties":{"enabled":{"default":true,"description":"the option
  to enable managed PDB","type":"boolean"},"maxUnavailable":{"anyOf":[{"pattern":".*%$","type":"string"},{"type":"integer"}],"default":1,"description":"maxUnavailable
  value for managed PDB, can be either string or integer; if it''s string, should
  end with %"},"minAvailable":{"anyOf":[{"pattern":".*%$","type":"string"},{"type":"integer"}],"description":"minAvailable
  value for managed PDB, can be either string or integer; if it''s string, should
  end with %"}},"type":"object"},"podLabels":{"properties":{},"title":"The podLabels
  Schema","type":"object"},"replicaCount":{"type":"integer"},"resources":{"$ref":"#/definitions/Resources"},"tolerations":{"default":[{"key":"CriticalAddonsOnly","operator":"Exists"},{"effect":"NoSchedule","key":"node-role.kubernetes.io/control-plane"}],"description":"Tolerations
  of the coredns pod","items":{"type":"object"},"type":"array"},"topologySpreadConstraints":{"description":"The
  coredns pod topology spread constraints","type":"array"}},"title":"Coredns","type":"object"},"Limits":{"additionalProperties":false,"properties":{"cpu":{"type":"string"},"memory":{"type":"string"}},"title":"Limits","type":"object"},"Resources":{"additionalProperties":false,"properties":{"limits":{"$ref":"#/definitions/Limits"},"requests":{"$ref":"#/definitions/Limits"}},"title":"Resources","type":"object"}}}'
```

## Destroy

To tear down and remove the resources created in the blueprint, complete the steps for [Amazon EKS Blueprints for Terraform - Destroy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy).

> [!TIP]
> The `destroy` phase can be orchestrated via the companion [Makefile](../../Makefile).
