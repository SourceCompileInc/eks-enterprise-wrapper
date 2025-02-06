# General Cluster Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "region" {
  description = "AWS region"
  type        = string
}

# VPC Configuration
variable "vpc_id" {
  description = "ID of the VPC where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs where the EKS cluster (ENIs) will be deployed. Must be in at least three different availability zones"
  type        = list(string)
}

# Node Groups Configuration
variable "managed_node_groups" {
  description = "Map of managed node group configurations"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    min_size      = number
    max_size      = number
    desired_size  = number
    disk_size     = number
    labels        = map(string)
    taints        = list(object({
      key    = string
      value  = string
      effect = string
    }))
    subnet_ids    = optional(list(string))
  }))
  default = {
    group1 = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      min_size      = 1
      max_size      = 3
      desired_size  = 1
      disk_size     = 50
      labels        = { role = "general" }
      taints        = []
    }
    group2 = {
      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
      min_size      = 1
      max_size      = 5
      desired_size  = 2
      disk_size     = 50
      labels        = { role = "apps" }
      taints        = []
    }
    group3 = {
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
      min_size      = 1
      max_size      = 3
      desired_size  = 1
      disk_size     = 50
      labels        = { role = "system" }
      taints        = []
    }
  }
}

# Cluster Addons
variable "cluster_addons" {
  description = "Map of cluster addon configurations"
  type = map(object({
    addon_version            = optional(string)
    resolve_conflicts        = optional(string, "OVERWRITE")
    service_account_role_arn = optional(string)
  }))
  default = {
    vpc-cni = {
      addon_version     = "v1.15.0-eksbuild.1"
      resolve_conflicts = "OVERWRITE"
    }
    coredns = {
      addon_version     = "v1.10.1-eksbuild.1"
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      addon_version     = "v1.28.1-eksbuild.1"
      resolve_conflicts = "OVERWRITE"
    }
  }
}

# Storage Configuration
variable "enable_efs_csi_driver" {
  description = "Enable EFS CSI driver addon"
  type        = bool
  default     = false
}

variable "efs_csi_driver_config" {
  description = "EFS CSI driver configuration"
  type = object({
    addon_version     = optional(string)
    resolve_conflicts = optional(string, "OVERWRITE")
    namespace         = optional(string, "kube-system")
    service_account   = optional(string, "efs-csi-controller-sa")
  })
  default = {
    addon_version     = "v1.5.8-eksbuild.1"
    resolve_conflicts = "OVERWRITE"
    namespace         = "kube-system"
    service_account   = "efs-csi-controller-sa"
  }
}

variable "enable_ebs_csi_driver" {
  description = "Enable EBS CSI driver addon"
  type        = bool
  default     = true
}

variable "ebs_csi_driver_config" {
  description = "EBS CSI driver configuration"
  type = object({
    addon_version     = optional(string)
    resolve_conflicts = optional(string, "OVERWRITE")
    namespace         = optional(string, "kube-system")
    service_account   = optional(string, "ebs-csi-controller-sa")
  })
  default = {
    addon_version     = "v1.25.0-eksbuild.1"
    resolve_conflicts = "OVERWRITE"
    namespace         = "kube-system"
    service_account   = "ebs-csi-controller-sa"
  }
}

# Logging Configuration
variable "cluster_enabled_log_types" {
  description = "A list of the desired control plane logs to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Number of days to retain log events in the CloudWatch log group"
  type        = number
  default     = 90
}

# Security Configuration
variable "cluster_encryption_config" {
  description = "Configuration block with encryption configuration for the cluster"
  type = list(object({
    provider_key_arn = string
    resources        = list(string)
  }))
  default = []
}

variable "cluster_security_group_additional_rules" {
  description = "Additional security group rules to add to the cluster security group"
  type = map(object({
    description                = string
    protocol                  = string
    from_port                 = number
    to_port                   = number
    type                      = string
    source_security_group_id  = optional(string)
    source_node_security_group = optional(bool)
    cidr_blocks              = optional(list(string))
    ipv6_cidr_blocks         = optional(list(string))
  }))
  default = {}
}

# IAM Configuration
variable "cluster_role_permissions_boundary" {
  description = "ARN of the policy that is used to set the permissions boundary for the cluster role"
  type        = string
  default     = null
}

variable "node_security_group_additional_rules" {
  description = "Additional security group rules to add to the node security group"
  type = map(object({
    description                = string
    protocol                  = string
    from_port                 = number
    to_port                   = number
    type                      = string
    source_security_group_id  = optional(string)
    source_cluster_security_group = optional(bool)
    cidr_blocks              = optional(list(string))
    ipv6_cidr_blocks         = optional(list(string))
  }))
  default = {}
}

# Tags
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# Authentication
variable "aws_auth_roles" {
  description = "List of role maps to add to the aws-auth configmap"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "aws_auth_users" {
  description = "List of user maps to add to the aws-auth configmap"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

# Auto Scaling
variable "cluster_autoscaler_enabled" {
  description = "Enable cluster autoscaler"
  type        = bool
  default     = true
}
