data "aws_route53_zone" "this" {
  name = var.domain_name
}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

locals {
  name   = "cbci-start-v4"
  region = "us-east-1"

  vpc_name     = "${local.name}-vpc"
  cluster_name = "${local.name}-eks"

  vpc_cidr = "10.0.0.0/16"

  #https://docs.cloudbees.com/docs/cloudbees-common/latest/supported-platforms/cloudbees-ci-cloud#_kubernetes
  k8s_version = "1.26"

  route53_zone_id     = data.aws_route53_zone.this.id
  azs                 = slice(data.aws_availability_zones.available.names, 0, 3)
  current_account_id  = data.aws_caller_identity.current.account_id
  current_account_arn = data.aws_caller_identity.current.arn

  cjoc_url = "https://cjoc.${var.domain_name}"

  tags = merge(var.tags, {
    "tf:blueprint"  = local.name
    "tf:repository" = "github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon"
  })
}

################################################################################
# EKS: Add-ons
################################################################################

module "eks_blueprints_addon_cbci" {
  source = "../../.."

  hostname     = var.domain_name
  cert_arn     = module.acm.acm_certificate_arn
  temp_license = var.temp_license

  depends_on = [
    module.eks_blueprints_addons
  ]
}

module "eks_blueprints_addons" {
  #IMPORTANT: DO NOT CHANGE THE REFERENCE TO THE MODULE
  #Since 4.32.1 to avoid https://github.com/aws-ia/terraform-aws-eks-blueprints/issues/1630#issuecomment-1577525242
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.32.1"

  eks_cluster_id       = module.eks.cluster_name
  eks_cluster_endpoint = module.eks.cluster_endpoint
  eks_oidc_provider    = module.eks.oidc_provider
  eks_cluster_version  = module.eks.cluster_version

  # Wait on the node group(s) before provisioning addons
  data_plane_wait_arn = join(",", [for group in module.eks.eks_managed_node_groups : group.node_group_arn])

  #Used by `ExternalDNS` to create DNS records in this Hosted Zone.
  eks_cluster_domain = var.domain_name

  # Add-ons
  enable_amazon_eks_aws_ebs_csi_driver = true
  enable_external_dns                  = true
  external_dns_helm_config = {
    values = [templatefile("${path.module}/extdns-values.yml", {
      zoneIdFilter = local.route53_zone_id
    })]
  }
  enable_aws_load_balancer_controller = true

  tags = local.tags
}

################################################################################
# EKS: Infra
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name                   = local.cluster_name
  cluster_version                = local.k8s_version
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  eks_managed_node_group_defaults = {
    block_device_mappings = {
      # Root volume
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 24
          volume_type           = "gp3"
          iops                  = 3000
          encrypted             = true
          kms_key_id            = module.ebs_kms_key.key_arn
          delete_on_termination = true
        }
      }
    }
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

  eks_managed_node_groups = {
    mg_k8sApps = {
      node_group_name = "managed-k8s-apps"
      instance_types  = ["m5d.4xlarge"]
      capacity_type   = "ON_DEMAND"
      desired_size    = 2
    }
  }

  tags = local.tags
}

module "ebs_kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "1.5.0"

  description = "Customer managed key to encrypt EKS managed node group volumes"

  # Policy
  key_administrators = [local.current_account_arn]
  key_service_roles_for_autoscaling = [
    "arn:aws:iam::${local.current_account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
    module.eks.cluster_iam_role_arn
  ]

  # Aliases
  aliases = ["eks/${local.name}/ebs"]

  tags = local.tags
}

resource "kubernetes_annotations" "gp2" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  force       = "true"

  metadata {
    name = "gp2"
  }

  annotations = {
    # Modify annotations to remove gp2 as default storage class still reatain the class
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  depends_on = [
    module.eks_blueprints_addons
  ]
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"

    annotations = {
      # Annotation to set gp3 as default storage class
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    encrypted = true
    fsType    = "ext4"
    type      = "gp3"
  }

  depends_on = [
    module.eks_blueprints_addons
  ]
}

################################################################################
# Supported Resources
################################################################################

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