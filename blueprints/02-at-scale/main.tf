data "aws_route53_zone" "this" {
  name = var.hosted_zone
}

data "aws_availability_zones" "available" {}

locals {

  name                      = var.suffix == "" ? "cbci-bp02" : "cbci-bp02-${var.suffix}"
  vpc_name                  = "${local.name}-vpc"
  cluster_name              = "${local.name}-eks"
  efs_name                  = "${local.name}-efs"
  resource_group_name       = "${local.name}-rg"
  bucket_name               = "${local.name}-s3"
  cbci_instance_profile_s3  = "${local.name}-instance_profile_s3"
  cbci_iam_role_s3          = "${local.name}-iam_role_s3"
  cbci_inline_policy_s3     = "${local.name}-iam_inline_policy_s3"
  cbci_instance_profile_ecr = "${local.name}-instance_profile_ecr"
  cbci_iam_role_ecr         = "${local.name}-iam_role_ecr"
  cbci_inline_policy_ecr    = "${local.name}-iam_inline_policy_ecr"

  vpc_cidr         = "10.0.0.0/16"
  azs              = slice(data.aws_availability_zones.available.names, 0, 3)
  route53_zone_id  = data.aws_route53_zone.this.id
  route53_zone_arn = data.aws_route53_zone.this.arn

  mng = {
    cbci_apps = {
      taints = {
        key    = "dedicated"
        value  = "cb-apps"
        effect = "NO_SCHEDULE"
      }
      labels = {
        role = "cb-apps"
      }
    }
  }

  cbci_s3_prefix        = "cbci"
  cbci_s3_location      = "${module.cbci_s3_bucket.s3_bucket_arn}/${local.cbci_s3_prefix}"
  fluentbit_s3_location = "${module.cbci_s3_bucket.s3_bucket_arn}/fluentbit"
  velero_s3_location    = "${module.cbci_s3_bucket.s3_bucket_arn}/velero"

  epoch_millis                    = time_static.epoch.unix * 1000
  cloudwatch_logs_expiration_days = 7
  s3_objects_expiration_days      = 90

  tags = merge(var.tags, {
    "tf-blueprint"  = local.name
    "tf-repository" = "github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon"
  })

}

################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.17.1"

  cluster_name                   = local.cluster_name
  cluster_endpoint_public_access = true
  #vK8#
  cluster_version = "1.29"

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
  }
  eks_managed_node_groups = {
    #Note: Openldap is not compatible with Bottlerocket or Graviton.
    shared_apps = {
      node_group_name = "shared"
      instance_types  = ["m5d.xlarge"]
      ami_type        = "AL2023_x86_64_STANDARD"
      platform        = "linux"
      min_size        = 1
      max_size        = 3
      desired_size    = 1
      labels = {
        role    = "shared"
        storage = "enabled"
      }
    }
    cb_apps = {
      node_group_name = "cb-apps"
      instance_types  = ["m7g.2xlarge"] #Graviton
      min_size        = 1
      max_size        = 6
      desired_size    = 1
      taints          = [local.mng["cbci_apps"]["taints"]]
      labels = {
        role    = local.mng["cbci_apps"]["labels"].role
        storage = "enabled"
      }
      create_iam_role            = false
      iam_role_arn               = aws_iam_role.managed_ng_s3.arn
      ami_type                   = "BOTTLEROCKET_ARM_64"
      platform                   = "bottlerocket"
      enable_bootstrap_user_data = true
      bootstrap_extra_args       = local.bottlerocket_bootstrap_extra_args
    }
    #https://aws.amazon.com/blogs/compute/cost-optimization-and-resilience-eks-with-spot-instances/
    #https://www.eksworkshop.com/docs/fundamentals/managed-node-groups/spot/instance-diversification
    cb_agents_lin_2x = {
      node_group_name = "agent-lin-2x"
      #ec2-instance-selector --vcpus 2 --memory 8 --region us-east-1 --deny-list 't.*' --current-generation -a arm64 --gpus 0 --usage-class spot
      instance_types = ["im4gn.large", "m6g.large", "m6gd.large", "m7g.large", "m7gd.large"] #Graviton
      capacity_type  = "SPOT"
      min_size       = 1
      max_size       = 3
      desired_size   = 1
      taints         = [{ key = "dedicated", value = "build-linux-l", effect = "NO_SCHEDULE" }]
      labels = {
        role = "build-linux-l"
        size = "2x"
      }
      create_iam_role            = false
      iam_role_arn               = aws_iam_role.managed_ng_ecr.arn
      ami_type                   = "BOTTLEROCKET_ARM_64"
      platform                   = "bottlerocket"
      enable_bootstrap_user_data = true
      bootstrap_extra_args       = local.bottlerocket_bootstrap_extra_args
    }
    cb_agents_lin_4x = {
      node_group_name = "agent-lin-4x"
      #ec2-instance-selector --vcpus 4 --memory 16 --region us-east-1 --deny-list 't.*' --current-generation -a arm64 --gpus 0 --usage-class spot
      instance_types = ["im4gn.xlarge", "m6g.xlarge", "m6gd.xlarge", "m7g.xlarge", "m7gd.xlarge"] #Graviton
      capacity_type  = "SPOT"
      min_size       = 0
      max_size       = 3
      desired_size   = 0
      taints         = [{ key = "dedicated", value = "build-linux-xl", effect = "NO_SCHEDULE" }]
      labels = {
        role = "build-linux-xl"
        size = "4x"
      }
      create_iam_role            = false
      iam_role_arn               = aws_iam_role.managed_ng_ecr.arn
      ami_type                   = "BOTTLEROCKET_ARM_64"
      platform                   = "bottlerocket"
      enable_bootstrap_user_data = true
      bootstrap_extra_args       = local.bottlerocket_bootstrap_extra_args
    }
    cb_agents_lin_8x = {
      node_group_name = "agent-lin-8x"
      #ec2-instance-selector --vcpus 8 --memory 32 --region us-east-1 --deny-list 't.*' --current-generation -a arm64 --gpus 0 --usage-class spot
      instance_types = ["im4gn.2xlarge", "m6g.2xlarge", "m6gd.2xlarge", "m7g.2xlarge", "m7gd.2xlarge"] #Graviton
      capacity_type  = "SPOT"
      min_size       = 0
      max_size       = 3
      desired_size   = 0
      taints         = [{ key = "dedicated", value = "build-linux-xl", effect = "NO_SCHEDULE" }]
      labels = {
        role = "build-linux-xl"
        size = "8x"
      }
      create_iam_role            = false
      iam_role_arn               = aws_iam_role.managed_ng_ecr.arn
      ami_type                   = "BOTTLEROCKET_ARM_64"
      platform                   = "bottlerocket"
      enable_bootstrap_user_data = true
      bootstrap_extra_args       = local.bottlerocket_bootstrap_extra_args
    }
    cb_agents_win = {
      node_group_name = "agent-win-4x"
      min_size        = 1
      max_size        = 3
      desired_size    = 1
      platform        = "windows"
      ami_type        = "WINDOWS_CORE_2019_x86_64"
      use_name_prefix = true
      #ec2-instance-selector --vcpus 4 --memory 16 --region us-east-1 --deny-list 't.*' --current-generation -a amd64 --gpus 0 --usage-class spot
      instance_types = ["m5.xlarge", "m5a.xlarge", "m5d.xlarge", "m5dn.xlarge", "m5n.xlarge", "m5zn.xlarge", "m6a.xlarge", "m6i.xlarge", "m6id.xlarge", "m6idn.xlarge", "m6in.xlarge", "m7a.xlarge", "m7i.xlarge"]
      capacity_type  = "SPOT"
      taints         = [{ key = "dedicated", value = "build-windows", effect = "NO_SCHEDULE" }]
      labels = {
        role = "build-windows"
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

resource "aws_iam_role" "managed_ng_s3" {
  name                  = local.cbci_iam_role_s3
  description           = "EKS Managed Node group IAM Role s3"
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
    name = local.cbci_inline_policy_s3
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
                "s3:prefix" : "${local.cbci_s3_prefix}/*"
              }
            }
          }
        ]
      }
    )
  }
  tags = var.tags
}

resource "aws_iam_instance_profile" "managed_ng_s3" {
  name = local.cbci_instance_profile_s3
  role = aws_iam_role.managed_ng_s3.name
  path = "/"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_iam_role" "managed_ng_ecr" {
  name                  = local.cbci_iam_role_ecr
  description           = "EKS Managed Node group IAM Role ECR"
  assume_role_policy    = data.aws_iam_policy_document.managed_ng_assume_role_policy.json
  path                  = "/"
  force_detach_policies = true
  # Mandatory for EKS Managed Node Group
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
  # Additional Permissions for for EKS Managed Node Group per https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html
  inline_policy {
    name = local.cbci_inline_policy_ecr
    policy = jsonencode(
      {
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Sid" : "ecrKaniko",
            "Effect" : "Allow",
            "Action" : [
              "ecr:GetDownloadUrlForLayer",
              "ecr:GetAuthorizationToken",
              "ecr:InitiateLayerUpload",
              "ecr:UploadLayerPart",
              "ecr:CompleteLayerUpload",
              "ecr:PutImage",
              "ecr:BatchGetImage",
              "ecr:BatchCheckLayerAvailability"
            ],
            "Resource" : "*"
          }
        ]
      }
    )
  }
  tags = var.tags
}

resource "aws_iam_instance_profile" "managed_ng_ecr" {
  name = local.cbci_instance_profile_ecr
  role = aws_iam_role.managed_ng_ecr.name
  path = "/"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
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
