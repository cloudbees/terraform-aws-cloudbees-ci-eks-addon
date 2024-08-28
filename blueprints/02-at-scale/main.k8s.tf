
locals {

  global_password      = random_string.global_pass_string.result
  global_pass_jsonpath = "'{.data.sec_globalPassword}'"

  bottlerocket_bootstrap_extra_args = <<-EOT
              [settings.host-containers.admin]
              enabled = false
              [settings.host-containers.control]
              enabled = true
              [settings.kernel]
              lockdown = "integrity"
              [settings.kubernetes.node-labels]
              "bottlerocket.aws/updater-interface-version" = "2.0.0"
            EOT

  #Velero Backups: Only for controllers using block storage (for example, Amazon EBS volumes in AWS)
  velero_controller_backup          = "team-b"
  velero_controller_backup_selector = "tenant=${local.velero_controller_backup}"
  velero_schedule_name              = "schedule-${local.velero_controller_backup}"

  hibernation_monitor_url = "https://hibernation-${module.eks_blueprints_addon_cbci.cbci_namespace}.${module.eks_blueprints_addon_cbci.cbci_domain_name}"
  cbci_admin_user         = "admin_cbci_a"
  cbci_agents_ns          = "cbci-agents"
  #K8S agent template name from the CasC bundle
  cbci_agent_linuxtempl   = "linux-mavenAndKaniko-"
  cbci_agent_windowstempl = "windows-powershell"

  vault_ns               = "vault"
  vault_config_file_path = abspath("k8s/vault-config.sh")
  vault_init_file_path   = abspath("k8s/vault-init.log")

  grafana_hostname = "grafana.${var.hosted_zone}"
  grafana_url      = "https://${local.grafana_hostname}"
}

resource "random_string" "global_pass_string" {
  length  = 16
  special = false
  upper   = true
  lower   = true
}

resource "time_static" "epoch" {
  depends_on = [module.eks_blueprints_addons]
}

################################################################################
# Workloads
################################################################################

# CloudBees CI Add-on

module "eks_blueprints_addon_cbci" {
  # source  = "cloudbees/cloudbees-ci-eks-addon/aws"
  # version = ">= 3.18072.0"
  source = "../../"

  depends_on = [module.eks_blueprints_addons]

  hosted_zone   = var.hosted_zone
  cert_arn      = module.acm.acm_certificate_arn
  trial_license = var.trial_license

  helm_config = {
    values = [templatefile("k8s/cbci-values.yml", {
      cbciAppsNodeRole        = local.mng["cbci_apps"]["labels"].role
      cbciAppsTolerationKey   = local.mng["cbci_apps"]["taints"].key
      cbciAppsTolerationValue = local.mng["cbci_apps"]["taints"].value
      cbciAgentsNamespace     = local.cbci_agents_ns
    })]
  }

  create_casc_secrets = true
  casc_secrets_file = templatefile("k8s/secrets-values.yml", {
    global_password = local.global_password
    s3bucketName    = local.bucket_name
    awsRegion       = var.aws_region
    adminMail       = var.trial_license["email"]
    grafana_url     = local.grafana_url
  })

  create_reg_secret = true
  reg_secret_ns     = local.cbci_agents_ns
  #Note: This blueprint tests DockerHub as container registry but different registries can be used.
  reg_secret_auth = {
    server   = "https://index.docker.io/v1/"
    username = var.dh_reg_secret_auth["username"]
    password = var.dh_reg_secret_auth["password"]
    email    = var.dh_reg_secret_auth["email"]
  }

  prometheus_target = true
  prometheus_target_ns = kubernetes_namespace.observability.metadata[0].name

}

# EKS Blueprints Add-ons

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.29.0"

  role_name_prefix = "${module.eks.cluster_name}-ebs-csi-driv"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

# It must be separate to correctly purge the observability
resource "kubernetes_namespace" "observability" {

  depends_on = [module.eks]
  metadata {
    name = "observability"
  }

}

module "eks_blueprints_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  #vEKSBpAddonsTFMod#
  version = "1.15.1"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  oidc_provider_arn = module.eks.oidc_provider_arn
  cluster_version   = module.eks.cluster_version

  eks_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
      configuration_values = jsonencode(
        {
          # ensure any PVC created also includes the custom tags
          controller = {
            extraVolumeTags = local.tags
          }
          # Deploy on the nodes that need Amazon EBS storage
          node = {
            nodeSelector = {
              storage = "enabled"
            }
          }
        }
      )
    }
    coredns = {
      timeouts = {
        create = "25m"
        delete = "10m"
      }
    }
    vpc-cni = {
      configuration_values = jsonencode(
        {
          enableWindowsIpam = "true"
        }
      )
    }
    kube-proxy = {}
  }
  #####################
  #01-getting-started
  #####################
  enable_external_dns = true
  external_dns = {
    values = [templatefile("k8s/extdns-values.yml", {
      zoneDNS = var.hosted_zone
    })]
  }
  external_dns_route53_zone_arns      = [local.route53_zone_arn]
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    values = [file("k8s/aws-alb-controller-values.yml")]
  }
  #####################
  #02-at-scale
  #####################
  enable_aws_efs_csi_driver = true
  aws_efs_csi_driver = {
    values = [file("k8s/aws-efs-csi-driver-values.yml")]
  }
  enable_metrics_server = true
  metrics_server = {
    values = [file("k8s/metrics-server-values.yml")]
  }
  enable_cluster_autoscaler = true
  cluster_autoscaler = {
    values = [file("k8s/cluster-autoscaler-values.yml")]
  }
  enable_velero = true
  velero = {
    values             = [file("k8s/velero-values.yml")]
    s3_backup_location = local.velero_s3_location
    set = [{
      name  = "initContainers"
      value = <<-EOT
      - name: velero-plugin-for-aws
        image: velero/velero-plugin-for-aws:v1.7.1
        imagePullPolicy: IfNotPresent
        volumeMounts:
          - mountPath: /target
            name: plugins
      #https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/restart-aborted-builds#_restarting_builds_after_a_restore
      - name: inject-metadata-velero-plugin
        image: ghcr.io/cloudbees-oss/inject-metadata-velero-plugin:main
        imagePullPolicy: Always
        volumeMounts:
          - mountPath: /target
            name: plugins
      EOT
    }]
  }
  enable_kube_prometheus_stack = true
  kube_prometheus_stack = {
    namespace        = kubernetes_namespace.observability.metadata[0].name
    create_namespace = false
    values = [templatefile("k8s/kube-prom-stack-values.yml", {
      grafana_password = local.global_password
      grafana_hostname = local.grafana_hostname
      cert_arn         = module.acm.acm_certificate_arn 
    })]
  }
  enable_aws_for_fluentbit = true
  aws_for_fluentbit_cw_log_group = {
    create          = true
    use_name_prefix = true # Set this to true to enable name prefix
    name_prefix     = "eks-cluster-logs-"
    retention       = local.cloudwatch_logs_expiration_days
  }
  aws_for_fluentbit = {
    #Enable Container Insights just for troubleshooting
    #https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html
    enable_containerinsights = false
    namespace = kubernetes_namespace.observability.metadata[0].name
    values = [templatefile("k8s/aws-for-fluent-bit-values.yml", {
      region             = var.aws_region
      bucketName         = module.cbci_s3_bucket.s3_bucket_id
      log_retention_days = local.cloudwatch_logs_expiration_days
    })]
    kubelet_monitoring = true
    chart_version      = "0.1.28"
    s3_bucket_arns = [
      module.cbci_s3_bucket.s3_bucket_arn,
      "${local.fluentbit_s3_location}/*"
    ]
  }
  #Cert Manager - Requirement for Bottlerocket Update Operator
  enable_cert_manager = true
  cert_manager = {
    wait = true
  }
  #Important: Update timing can be customized
  #Bottlerocket Update Operator
  enable_bottlerocket_update_operator = true
  bottlerocket_update_operator = {
    values = [file("k8s/br-update-operator-values.yml")]
  }
  #####################
  #Additional Helm Releases
  #####################
  helm_releases = {
    openldap-stack = {
      chart            = "openldap-stack-ha"
      chart_version    = "4.2.2"
      namespace        = "auth"
      create_namespace = true
      repository       = "https://jp-gouin.github.io/helm-openldap/"
      values = [templatefile("k8s/openldap-stack-values.yml", {
        password           = local.global_password
        admin_user_outputs = local.cbci_admin_user
      })]
    }
    aws-node-termination-handler = {
      name             = "aws-node-termination-handler"
      namespace        = "kube-system"
      create_namespace = false
      chart            = "aws-node-termination-handler"
      chart_version    = "0.21.0"
      repository       = "https://aws.github.io/eks-charts"
      values           = [file("k8s/aws-node-term-handler-values.yml")]
    }
    #Based on hashicorp/hashicorp-vault-eks-addon/aws
    vault = {
      name             = "vault"
      namespace        = local.vault_ns
      create_namespace = true
      chart            = "vault"
      chart_version    = "0.28.0"
      repository       = "https://helm.releases.hashicorp.com"
      values           = [file("k8s/vault-values.yml")]
    }
    otel-collector = {
      name             = "otel-collector"
      namespace        = kubernetes_namespace.observability.metadata[0].name
      create_namespace = true
      chart            = "opentelemetry-collector"
      chart_version    = "0.102.1"
      repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
      values           = [file("k8s/otel-collector-values.yml")]
    }
    jaeger = {
      name             = "jaeger"
      namespace        = kubernetes_namespace.observability.metadata[0].name
      create_namespace = true
      chart            = "jaeger"
      chart_version    = "3.1.2"
      repository       = "https://jaegertracing.github.io/helm-charts"
      values           = [file("k8s/jaeger-values.yml")]
    }

  }

  tags = local.tags
}

################################################################################
# Storage Classes
################################################################################

resource "kubernetes_annotations" "gp2" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  # This is true because the resources was already created by the ebs-csi-driver addon
  force = "true"

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"

    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    encrypted = "true"
    fsType    = "ext4"
    type      = "gp3"
  }

}

resource "kubernetes_storage_class_v1" "efs" {

  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Delete"
  parameters = {
    # Dynamic provisioning
    provisioningMode = "efs-ap"
    fileSystemId     = module.efs.id
    directoryPerms   = "700"
    #Issue #190
    uid = "1000"
    gid = "1000"
  }

  mount_options = [
    "iam"
  ]
}

################################################################################
# Kubeconfig
################################################################################

resource "terraform_data" "create_kubeconfig" {
  depends_on = [module.eks]

  triggers_replace = var.ci ? [timestamp()] : []

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --kubeconfig ${local.kubeconfig_file_path}"
  }
}