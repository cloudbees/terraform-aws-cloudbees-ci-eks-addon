data "aws_route53_zone" "this" {
  name = var.hosted_zone
}

locals {
  name   = var.suffix == "" ? "cbci-bp02" : "cbci-bp02-${var.suffix}"
  region = "us-east-1"
  #Number of AZs per region https://docs.aws.amazon.com/ram/latest/userguide/working-with-az-ids.html
  azs = ["${local.region}a", "${local.region}b", "${local.region}c"]

  vpc_name              = "${local.name}-vpc"
  cluster_name          = "${local.name}-eks"
  efs_name              = "${local.name}-efs"
  resource_group_name   = "${local.name}-rg"
  bucket_name           = "${local.name}-s3"
  cbci_instance_profile = "${local.name}-instance_profile"
  cbci_iam_role         = "${local.name}-iam_role_mn"
  kubeconfig_file       = "kubeconfig_${local.name}.yaml"
  kubeconfig_file_path  = abspath("k8s/${local.kubeconfig_file}")

  hibernation_monitor_url = "https://hibernation-${module.eks_blueprints_addon_cbci.cbci_namespace}.${module.eks_blueprints_addon_cbci.cbci_domain_name}"

  vpc_cidr = "10.0.0.0/16"

  mng = {
    cbci_apps = {
      taints = {
        key    = "dedicated"
        value  = "cb-apps"
        effect = "NO_SCHEDULE"
      }
      labels = {
        ci_type = "cb-apps"
      }
    }

  }

  cbci_apps_labels_yaml = replace(yamlencode(local.mng["cbci_apps"]["labels"]), "/\"/", "")

  route53_zone_id  = data.aws_route53_zone.this.id
  route53_zone_arn = data.aws_route53_zone.this.arn

  tags = merge(var.tags, {
    "tf-blueprint"  = local.name
    "tf-repository" = "github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon"
  })

  #s3 application prefixes
  cbci_s3_location      = "${module.cbci_s3_bucket.s3_bucket_arn}/cbci"
  fluentbit_s3_location = "${module.cbci_s3_bucket.s3_bucket_arn}/fluentbit"
  velero_s3_location    = "${module.cbci_s3_bucket.s3_bucket_arn}/velero"

  epoch_millis    = time_static.epoch.unix * 1000
  global_password = random_string.global_pass_string.result

  cloudwatch_logs_expiration_days = 7
  s3_objects_expiration_days      = 90

  # Validation Phase for Terraform Outputs

  #Velero Backups: Only for controllers using block storage (for example, Amazon EBS volumes in AWS)
  velero_controller_backup          = "team-b"
  velero_controller_backup_selector = "tenant=${local.velero_controller_backup}"
  velero_schedule_name              = "schedule-${local.velero_controller_backup}"

  cbci_agents_ns                     = "cbci-agents"
  cbci_agent_podtemplname_validation = "maven-and-go-ondemand"

  cbci_admin_user      = "admin_cbci_a"
  global_pass_jsonpath = "'{.data.sec_globalPassword}'"
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
# EKS: Add-ons
################################################################################

# CloudBees CI Add-ons

module "eks_blueprints_addon_cbci" {
  source = "../../"
  #source  = "cloudbees/cloudbees-ci-eks-addon/aws"
  #version = ">= 3.17108.0"

  hosted_zone   = var.hosted_zone
  cert_arn      = module.acm.acm_certificate_arn
  trial_license = var.trial_license

  helm_config = {
    values = [templatefile("k8s/cbci-values.yml", {
      cbciAppsSelector        = local.cbci_apps_labels_yaml
      cbciAppsTolerationKey   = local.mng["cbci_apps"]["taints"].key
      cbciAppsTolerationValue = local.mng["cbci_apps"]["taints"].value
      cbciAgentsNamespace     = local.cbci_agents_ns
    })]
  }

  create_k8s_secrets = true
  # k8s/secrets-values.yml is not included in the repository
  # tflint-ignore: all
  k8s_secrets = templatefile("k8s/secrets-values.yml", {
    global_password = local.global_password
  })

  prometheus_target = true

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
      # ensure any PVC created also includes the custom tags
      configuration_values = jsonencode(
        {
          controller = {
            extraVolumeTags = local.tags
          }
        }
      )
    }
    coredns    = {}
    vpc-cni    = {}
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
  #####################
  #02-at-scale
  #####################
  enable_aws_efs_csi_driver = true
  enable_metrics_server     = true
  enable_cluster_autoscaler = true
  enable_velero             = true
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
    values = [file("k8s/kube-prom-stack-values.yml")]
    set_sensitive = [
      {
        name  = "grafana.adminPassword"
        value = local.global_password
      }
    ]
  }
  enable_aws_for_fluentbit = true
  aws_for_fluentbit_cw_log_group = {
    create          = true
    use_name_prefix = true # Set this to true to enable name prefix
    name_prefix     = "eks-cluster-logs-"
  }
  aws_for_fluentbit = {
    #Enable Container Insights just for troubleshooting
    #https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html
    enable_containerinsights = false
    values = [templatefile("k8s/aws-for-fluent-bit-values.yml", {
      region             = local.region
      bucketName         = module.cbci_s3_bucket.s3_bucket_id
      log_retention_days = local.cloudwatch_logs_expiration_days
    })]
    kubelet_monitoring = true
    chart_version      = "0.1.28"
    set = [{
      name  = "cloudWatchLogs.autoCreateGroup"
      value = true
      },
      {
        name  = "hostNetwork"
        value = true
      },
      {
        name  = "dnsPolicy"
        value = "ClusterFirstWithHostNet"
      }
    ]
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
    values = [file("k8s/bottlerocket-update-operator.yml")]
  }
  #Additional Helm Releases
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
      name          = "aws-node-termination-handler"
      namespace     = "kube-system"
      chart         = "aws-node-termination-handler"
      chart_version = "0.21.0"
      repository    = "https://aws.github.io/eks-charts"
      values = [
        <<-EOT
          nodeSelector:
            ci_type: build-linux-spot
        EOT
      ]
    }
    grafana-tempo = {
      name          = "tempo"
      namespace     = "kube-prometheus-stack"
      chart         = "tempo"
      chart_version = "1.7.2"
      repository    = "https://grafana.github.io/helm-charts"
      values = [
        <<-EOT
          tempoQuery:
            enabled: true
        EOT
      ]
    }
  }

  tags = local.tags
}

################################################################################
# EKS: Infra
################################################################################

# EKS Cluster

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.17.1"

  cluster_name                   = local.cluster_name
  cluster_endpoint_public_access = true
  #vK8#
  cluster_version = "1.28"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Security groups based on the best practices doc https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html.
  #   So, by default the security groups are restrictive. Users needs to enable rules for specific ports required for App requirement or Add-ons
  #   See the notes below for each rule used in these examples
  node_security_group_additional_rules = {
    # Recommended outbound traffic for Node groups
    egress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      self        = true
    }
    # Extend node-to-node security group rules. Recommended and required for the Add-ons
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    egress_ssh_all = {
      description      = "Egress all ssh to internet for github"
      protocol         = "tcp"
      from_port        = 22
      to_port          = 22
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

    # Allows Control Plane Nodes to talk to Worker nodes on all ports. Added this to simplify the example and further avoid issues with Add-ons communication with Control plane.
    # This can be restricted further to specific port based on the requirement for each Add-on e.g., metrics-server 4443, spark-operator 8080, karpenter 8443 etc.
    # Change this according to your security requirements if needed
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  #https://docs.aws.amazon.com/eks/latest/userguide/choosing-instance-type.html
  #https://docs.aws.amazon.com/eks/latest/APIReference/API_Nodegroup.html
  eks_managed_node_group_defaults = {
    capacity_type = "ON_DEMAND"
    disk_size     = 50
    #Bottlerocket configuration. All Nodes groups are Bottlerocket but common_apps
    ami_type = "BOTTLEROCKET_ARM_64"
    platform = "bottlerocket"
    #BottleRocket Settings: https://bottlerocket.dev/en/os/1.19.x/api/settings/
    enable_bootstrap_user_data = true
    bootstrap_extra_args       = <<-EOT
            [settings.host-containers.admin]
            enabled = false
            [settings.host-containers.control]
            enabled = true
            [settings.kernel]
            lockdown = "integrity"
            [settings.kubernetes.node-labels]
            "bottlerocket.aws/updater-interface-version" = "2.0.0"
          EOT
  }
  eks_managed_node_groups = {
    #Note: osixia/openldap is not compatible either Bottlerocket, neither Graviton.
    common_apps = {
      node_group_name            = "mg-common-apps"
      instance_types             = ["m5d.xlarge"]
      ami_type                   = "AL2023_x86_64_STANDARD"
      platform                   = "linux"
      min_size                   = 1
      max_size                   = 3
      desired_size               = 1
      enable_bootstrap_user_data = false
      bootstrap_extra_args       = <<-EOT
          EOT
    }
    cb_apps = {
      node_group_name = "mg-cb-apps"
      instance_types  = ["m7g.2xlarge"] #Graviton
      min_size        = 1
      max_size        = 6
      desired_size    = 1
      taints          = [local.mng["cbci_apps"]["taints"]]
      labels          = local.mng["cbci_apps"]["labels"]
      create_iam_role = false
      iam_role_arn    = aws_iam_role.managed_ng.arn
    }
    cb_agents_2x = {
      node_group_name = "mg-agent-2x"
      instance_types  = ["m7g.large"] #Graviton
      min_size        = 1
      max_size        = 3
      desired_size    = 1
      taints          = [{ key = "dedicated", value = "build-linux", effect = "NO_SCHEDULE" }]
      labels = {
        ci_type = "build-linux"
      }
    }
    #https://aws.amazon.com/blogs/compute/cost-optimization-and-resilience-eks-with-spot-instances/
    #https://www.eksworkshop.com/docs/fundamentals/managed-node-groups/spot/instance-diversification
    cb_agents_spot_4x = {
      node_group_name = "mng-agent-spot-4x"
      #ec2-instance-selector --vcpus 4 --memory 16 --region us-east-1 --deny-list 't.*' --current-generation -a arm64 --gpus 0 --usage-class spot
      instance_types = ["im4gn.xlarge", "m6g.xlarge", "m6gd.xlarge", "m7g.xlarge", "m7gd.xlarge"] #Graviton
      capacity_type  = "SPOT"
      min_size       = 0
      max_size       = 3
      desired_size   = 0
      taints         = [{ key = "dedicated", value = "build-linux-spot", effect = "NO_SCHEDULE" }]
      labels = {
        ci_type = "build-linux-spot"
      }
    }
    cb_agents_spot_8x = {
      node_group_name = "mng-agent-spot-8x"
      #ec2-instance-selector --vcpus 8 --memory 32 --region us-east-1 --deny-list 't.*' --current-generation -a arm64 --gpus 0 --usage-class spot
      instance_types = ["im4gn.2xlarge", "m6g.2xlarge", "m6gd.2xlarge", "m7g.2xlarge", "m7gd.2xlarge"] #Graviton
      capacity_type  = "SPOT"
      min_size       = 0
      max_size       = 3
      desired_size   = 0
      taints         = [{ key = "dedicated", value = "build-linux-spot", effect = "NO_SCHEDULE" }]
      labels = {
        ci_type = "build-linux-spot"
      }
    }
  }

  #https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  #https://aws.amazon.com/blogs/containers/understanding-and-cost-optimizing-amazon-eks-control-plane-logs/
  create_cloudwatch_log_group            = true
  cluster_enabled_log_types              = ["audit", "api", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = local.cloudwatch_logs_expiration_days

  tags = local.tags
}

# AWS Instance Permissions

data "aws_iam_policy_document" "managed_ng_assume_role_policy" {
  statement {
    sid = "EKSWorkerAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "managed_ng" {
  name                  = local.cbci_iam_role
  description           = "EKS Managed Node group IAM Role"
  assume_role_policy    = data.aws_iam_policy_document.managed_ng_assume_role_policy.json
  path                  = "/"
  force_detach_policies = true
  # Mandatory for EKS Managed Node Group
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
  # Additional Permissions for for EKS Managed Node Group per https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html
  inline_policy {
    name = "${local.name}-iam_inline_policy"
    policy = jsonencode(
      {
        "Version" : "2012-10-17",
        #https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/cloudbees-cache-step#_s3_configuration
        "Statement" : [
          {
            "Sid" : "cbciS3BucketputGetDelete",
            "Effect" : "Allow",
            "Action" : [
              "s3:PutObject",
              "s3:GetObject",
              "s3:DeleteObject"
            ],
            "Resource" : "${local.cbci_s3_location}/*"
          },
          {
            "Sid" : "cbciS3BucketList",
            "Effect" : "Allow",
            "Action" : "s3:ListBucket",
            "Resource" : module.cbci_s3_bucket.s3_bucket_arn
            "Condition" : {
              "StringLike" : {
                "s3:prefix" : "cbci/*"
              }
            }
          },
        ]
      }
    )
  }
  tags = var.tags
}

resource "aws_iam_instance_profile" "managed_ng" {
  name = local.cbci_instance_profile
  role = aws_iam_role.managed_ng.name
  path = "/"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# Storage Classes

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
    provisioningMode = "efs-ap" # Dynamic provisioning
    fileSystemId     = module.efs.id
    directoryPerms   = "700"
  }

  mount_options = [
    "iam"
  ]
}

# Kubeconfig

resource "null_resource" "create_kubeconfig" {

  depends_on = [module.eks]

  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${local.region} --kubeconfig ${local.kubeconfig_file_path}"
  }
}

################################################################################
# Supported Resources
################################################################################

module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "1.6.0"

  creation_token = local.efs_name
  name           = local.efs_name

  mount_targets = {
    for k, v in zipmap(local.azs, module.vpc.private_subnets) : k => { subnet_id = v }
  }
  security_group_description = "${local.efs_name} EFS security group"
  security_group_vpc_id      = module.vpc.vpc_id
  #https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/eks-pre-install-requirements-helm#_storage_requirements
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"
  security_group_rules = {
    vpc = {
      # relying on the defaults provdied for EFS/NFS (2049/TCP + ingress)
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
  }

  #Issue #39
  enable_backup_policy = false

  tags = var.tags
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.0.0"

  #Important: Application Services Hostname must be the same as the domain name or subject_alternative_names
  domain_name = var.hosted_zone
  subject_alternative_names = [
    "*.${var.hosted_zone}" # For subdomains example.${var.domain_name}
  ]

  #https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html
  zone_id           = local.route53_zone_id
  validation_method = "DNS"

  tags = local.tags
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.2"

  name = local.vpc_name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  #https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
  #https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags

}

resource "aws_resourcegroups_group" "bp_rg" {
  name = local.resource_group_name

  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::AllSupported"
  ],
  "TagFilters": [
    {
      "Key": "tf-blueprint",
      "Values": ["${local.name}"]
    }
  ]
}
JSON
  }
}

module "cbci_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.0.1"

  bucket = local.bucket_name

  # Allow deletion of non-empty bucket
  # NOTE: This is enabled for example usage only, you should not enable this for production workloads
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  acl = "private"

  # S3 bucket-level Public Access Block configuration (by default now AWS has made this default as true for S3 bucket-level block public access)
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  #SECO-3109
  object_lock_enabled = false

  versioning = {
    status     = true
    mfa_delete = false
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  #https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html
  #https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration
  lifecycle_rule = [
    {
      #Use multiple rules to apply different transitions and expiration based on filters (prefix, tags, etc)
      id      = "general"
      enabled = true

      transition = [
        {
          days          = 30
          storage_class = "ONEZONE_IA"
          }, {
          days          = 60
          storage_class = "GLACIER"
        }
      ]

      expiration = {
        days                         = local.s3_objects_expiration_days
        expired_object_delete_marker = true
      }
    }
  ]

  tags = local.tags
}
