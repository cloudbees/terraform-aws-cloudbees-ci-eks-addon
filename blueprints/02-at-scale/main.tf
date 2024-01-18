data "aws_route53_zone" "this" {
  name = var.domain_name
}

locals {
  name   = var.suffix == "" ? "cbci-bp02" : "cbci-bp02-${var.suffix}"
  region = "us-east-1"
  #Number of AZs per region https://docs.aws.amazon.com/ram/latest/userguide/working-with-az-ids.html
  azs = ["${local.region}a", "${local.region}b", "${local.region}c"]
  #For g3 SC
  az_a = ["${local.region}a"]

  vpc_name             = "${local.name}-vpc"
  cluster_name         = "${local.name}-eks"
  efs_name             = "${local.name}-efs"
  resource_group_name  = "${local.name}-rg"
  bucket_name          = "${local.name}-s3"
  kubeconfig_file      = "kubeconfig_${local.name}.yaml"
  kubeconfig_file_path = abspath("k8s/${local.kubeconfig_file}")

  hibernation_monitor_url = "https://hibernation-${module.eks_blueprints_addon_cbci.cbci_namespace}.${module.eks_blueprints_addon_cbci.cbci_domain_name}"

  vpc_cidr = "10.0.0.0/16"

  #https://docs.cloudbees.com/docs/cloudbees-common/latest/supported-platforms/cloudbees-ci-cloud#_kubernetes
  k8s_version = "1.27"

  k8s_instance_types = {
    # Not Scalable
    "k8s-apps" = ["m5.8xlarge"]
    # Scalable
    "cb-apps"    = ["m5d.4xlarge"] #https://aws.amazon.com/about-aws/whats-new/2018/06/introducing-amazon-ec2-m5d-instances/
    "agent"      = ["m5.2xlarge"]
    "agent-spot" = ["m5.2xlarge"]
  }

  route53_zone_id  = data.aws_route53_zone.this.id
  route53_zone_arn = data.aws_route53_zone.this.arn

  tags = merge(var.tags, {
    "tf-blueprint"  = local.name
    "tf-repository" = "github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon"
  })

  velero_s3_backup_location = "${module.cbci_s3_bucket.s3_bucket_arn}/velero"
  velero_bk_demo            = "team-a-pvc-bk"
  velero_bk_freq            = "@every 30m"
  velero_bk_ttl             = "2h"

}

################################################################################
# EKS: Add-ons
################################################################################

# CloudBees CI Add-ons

module "eks_blueprints_addon_cbci" {
  source = "../../"

  hostname     = var.domain_name
  cert_arn     = module.acm.acm_certificate_arn
  temp_license = var.temp_license

  helm_config = {
    create_namespace = false
    values           = [file("k8s/cbci-values.yml")]
  }

  secrets_file = "k8s/secrets-values.yml"

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

#Issue 23
# data "aws_autoscaling_groups" "eks_node_groups" {
#   depends_on = [module.eks]
#   filter {
#     name   = "tag-key"
#     values = ["eks:cluster-name"]
#   }
# }

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.12.0"

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
  #01-getting-started
  enable_external_dns = true
  external_dns = {
    values = [templatefile("k8s/extdns-values.yml", {
      zoneDNS = var.domain_name
    })]
  }
  external_dns_route53_zone_arns      = [local.route53_zone_arn]
  enable_aws_load_balancer_controller = true
  #02-at-scale
  enable_aws_efs_csi_driver = true
  enable_metrics_server     = true
  enable_cluster_autoscaler = true
  #Issue 23
  #enable_aws_node_termination_handler   = false
  #aws_node_termination_handler_asg_arns = data.aws_autoscaling_groups.eks_node_groups.arns
  enable_velero = true
  velero = {
    s3_backup_location = local.velero_s3_backup_location
  }

  enable_kube_prometheus_stack = true
  kube_prometheus_stack = {
    values = [
      file("k8s/kube-prometheus-stack-values.yml"),
    ]
    set_sensitive = [
      {
        name  = "grafana.adminPassword"
        value = var.grafana_admin_password
      }
    ]
  }

  enable_aws_for_fluentbit = true
  aws_for_fluentbit = {
    enable_containerinsights = true
    values                   = [file("k8s/aws-for-fluent-bit-values.yml")]
  }

  tags = local.tags
}

resource "null_resource" "velero_schedules" {

  provisioner "local-exec" {
    #Create a schedule per controller using EBS. In this example, we are creating a schedule for team-a
    command = "velero delete schedule ${local.velero_bk_demo}  --confirm || echo '${local.velero_bk_demo} does not yet exists'; velero create schedule ${local.velero_bk_demo} --schedule='${local.velero_bk_freq}' --ttl ${local.velero_bk_ttl} --include-namespaces ${module.eks_blueprints_addon_cbci.cbci_namespace} --exclude-resources pods,events,events.events.k8s.io --selector tenant=team-a"
    environment = {
      KUBECONFIG = local.kubeconfig_file_path
    }
  }

}

resource "kubectl_manifest" "service_monitor_cb_controllers" {

  depends_on = [module.eks_blueprints_addons]

  yaml_body = file("k8s/kube-prometheus-stack-sm.yml")
}

################################################################################
# EKS: Infra
################################################################################

# EKS Cluster

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name                   = local.cluster_name
  cluster_version                = local.k8s_version
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    disk_size = 50
  }

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

  #https://aws.amazon.com/blogs/containers/amazon-eks-cluster-multi-zone-auto-scaling-groups/
  eks_managed_node_groups = {
    mg_k8sApps = {
      node_group_name = "mg-k8s-apps"
      instance_types  = local.k8s_instance_types["k8s-apps"]
      capacity_type   = "ON_DEMAND"
      min_size        = 1
      max_size        = 3
      desired_size    = 1
    }
    mg_cbApps = {
      node_group_name = "mng-cb-apps"
      instance_types  = local.k8s_instance_types["cb-apps"]
      capacity_type   = "ON_DEMAND"
      min_size        = 1
      max_size        = 6
      desired_size    = 1
      taints          = [{ key = "dedicated", value = "cb-apps", effect = "NO_SCHEDULE" }]
      labels = {
        ci_type = "cb-apps"
      }
      create_iam_role = false
      iam_role_arn    = aws_iam_role.managed_ng.arn
    }
    mg_cbAgents = {
      node_group_name = "mng-agent"
      instance_types  = local.k8s_instance_types["agent"]
      capacity_type   = "ON_DEMAND"
      min_size        = 1
      max_size        = 3
      desired_size    = 1
      taints          = [{ key = "dedicated", value = "build-linux", effect = "NO_SCHEDULE" }]
      labels = {
        ci_type = "build-linux"
      }
    }
    mg_cbAgents_spot = {
      node_group_name = "mng-agent-spot"
      instance_types  = local.k8s_instance_types["agent-spot"]
      capacity_type   = "SPOT"
      min_size        = 1
      max_size        = 3
      desired_size    = 1
      taints          = [{ key = "dedicated", value = "build-linux-spot", effect = "NO_SCHEDULE" }]
      labels = {
        ci_type = "build-linux-spot"
      }
    }
  }

  #https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  create_cloudwatch_log_group = true
  cluster_enabled_log_types   = ["audit", "api", "authenticator", "controllerManager", "scheduler"]

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
  name                  = "${local.name}-iam_role_mn"
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
            "Resource" : "arn:aws:s3:::${module.cbci_s3_bucket.s3_bucket_id}/cbci/*"
          },
          {
            "Sid" : "cbciS3BucketList",
            "Effect" : "Allow",
            "Action" : "s3:ListBucket",
            "Resource" : "arn:aws:s3:::${module.cbci_s3_bucket.s3_bucket_id}"
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
  name = "${local.name}-instance_profile"
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

  allowed_topologies {
    match_label_expressions {
      key    = "topology.ebs.csi.aws.com/zone"
      values = local.az_a
    }
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

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${local.region} --kubeconfig ${local.kubeconfig_file_path}"
  }
}

################################################################################
# Supported Resources
################################################################################

module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "1.2.0"

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

  # Backup policy
  enable_backup_policy = true

  tags = var.tags
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "4.3.2"

  #Important: Application Services Hostname must be the same as the domain name or subject_alternative_names
  domain_name = var.domain_name
  subject_alternative_names = [
    "*.${var.domain_name}" # For subdomains example.${var.domain_name}
  ]

  #https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html
  zone_id = local.route53_zone_id

  tags = local.tags
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

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
  version = "~> 3.0"

  bucket = local.bucket_name

  # Allow deletion of non-empty bucket
  # NOTE: This is enabled for example usage only, you should not enable this for production workloads
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  acl = "private"

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

  tags = local.tags
}
