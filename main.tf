provider "aws" {
  region = var.region
}

locals {
  cluster_name = var.cluster_name
  tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
      "Environment"                                 = "production"
      "Terraform"                                  = "true"
    }
  )
}

# EKS Cluster
module "eks" {
  source = "./modules/terraform-aws-eks"
  version = "20.33.1"

  cluster_name                   = local.cluster_name
  cluster_version               = var.cluster_version
  cluster_enabled_log_types     = var.cluster_enabled_log_types
  cluster_encryption_config     = var.cluster_encryption_config

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Managed Node Groups
  eks_managed_node_groups = var.managed_node_groups

  # Cluster Security Group
  create_cluster_security_group = true
  cluster_security_group_additional_rules = var.cluster_security_group_additional_rules

  # Node Security Group
  create_node_security_group = true
  node_security_group_additional_rules = var.node_security_group_additional_rules

  # IAM
  create_iam_role = true
  iam_role_permissions_boundary = var.cluster_role_permissions_boundary

  # AWS Auth
  manage_aws_auth_configmap = true
  aws_auth_roles           = var.aws_auth_roles
  aws_auth_users           = var.aws_auth_users

  tags = local.tags
}

# VPC CNI Addon
resource "aws_eks_addon" "vpc_cni" {
  count = lookup(var.cluster_addons, "vpc-cni", null) != null ? 1 : 0

  cluster_name = module.eks.cluster_name
  addon_name   = "vpc-cni"
  
  addon_version            = try(var.cluster_addons["vpc-cni"].addon_version, null)
  resolve_conflicts        = try(var.cluster_addons["vpc-cni"].resolve_conflicts, "OVERWRITE")
  service_account_role_arn = try(var.cluster_addons["vpc-cni"].service_account_role_arn, null)

  depends_on = [module.eks]
}

# CoreDNS Addon
resource "aws_eks_addon" "coredns" {
  count = lookup(var.cluster_addons, "coredns", null) != null ? 1 : 0

  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"
  
  addon_version            = try(var.cluster_addons["coredns"].addon_version, null)
  resolve_conflicts        = try(var.cluster_addons["coredns"].resolve_conflicts, "OVERWRITE")
  service_account_role_arn = try(var.cluster_addons["coredns"].service_account_role_arn, null)

  depends_on = [module.eks]
}

# kube-proxy Addon
resource "aws_eks_addon" "kube_proxy" {
  count = lookup(var.cluster_addons, "kube-proxy", null) != null ? 1 : 0

  cluster_name = module.eks.cluster_name
  addon_name   = "kube-proxy"
  
  addon_version            = try(var.cluster_addons["kube-proxy"].addon_version, null)
  resolve_conflicts        = try(var.cluster_addons["kube-proxy"].resolve_conflicts, "OVERWRITE")
  service_account_role_arn = try(var.cluster_addons["kube-proxy"].service_account_role_arn, null)

  depends_on = [module.eks]
}

# EBS CSI Driver
module "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  source = "./modules/terraform-aws-eks-ebs-csi-driver"
  version = "2.10.1"

  cluster_name = module.eks.cluster_name
  iam_role_name = "${local.cluster_name}-ebs-csi-controller"

  addon_config = {
    addon_name               = "aws-ebs-csi-driver"
    addon_version           = var.ebs_csi_driver_config.addon_version
    service_account_role_arn = module.ebs_csi_irsa_role[0].iam_role_arn
    resolve_conflicts       = var.ebs_csi_driver_config.resolve_conflicts
  }

  depends_on = [module.eks]
}

# EBS CSI Driver IRSA Role
module "ebs_csi_irsa_role" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.ebs_csi_driver_config.namespace}:${var.ebs_csi_driver_config.service_account}"]
    }
  }

  tags = local.tags
}

# EFS CSI Driver
module "efs_csi_driver" {
  count = var.enable_efs_csi_driver ? 1 : 0

  source = "./modules/terraform-aws-eks-efs-csi-driver"
  version = "2.2.7"

  cluster_name = module.eks.cluster_name
  iam_role_name = "${local.cluster_name}-efs-csi-controller"

  addon_config = {
    addon_name               = "aws-efs-csi-driver"
    addon_version           = var.efs_csi_driver_config.addon_version
    service_account_role_arn = module.efs_csi_irsa_role[0].iam_role_arn
    resolve_conflicts       = var.efs_csi_driver_config.resolve_conflicts
  }

  depends_on = [module.eks]
}

# EFS CSI Driver IRSA Role
module "efs_csi_irsa_role" {
  count = var.enable_efs_csi_driver ? 1 : 0

  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-efs-csi"
  attach_efs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.efs_csi_driver_config.namespace}:${var.efs_csi_driver_config.service_account}"]
    }
  }

  tags = local.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  tags              = local.tags
}
