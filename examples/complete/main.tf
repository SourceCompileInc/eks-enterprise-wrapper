provider "aws" {
  region = "us-west-2"  # Change this to your desired region
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.4.0"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}

module "eks" {
  source = "../../"  # Points to our local wrapper module

  cluster_name    = "example-eks-cluster"
  cluster_version = "1.28"
  region          = "us-west-2"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Node Groups Configuration
  managed_node_groups = {
    general = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      min_size      = 1
      max_size      = 3
      desired_size  = 1
      disk_size     = 50
      labels = {
        role = "general"
      }
      taints = []
    }
    apps = {
      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
      min_size      = 1
      max_size      = 5
      desired_size  = 2
      disk_size     = 50
      labels = {
        role = "apps"
      }
      taints = []
    }
    system = {
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
      min_size      = 1
      max_size      = 3
      desired_size  = 1
      disk_size     = 50
      labels = {
        role = "system"
      }
      taints = []
    }
  }

  # Cluster Addons
  cluster_addons = {
    vpc-cni = {
      addon_version     = "v1.15.4-eksbuild.1"
      resolve_conflicts = "OVERWRITE"
    }
    coredns = {
      addon_version     = "v1.11.1-eksbuild.4"
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      addon_version     = "v1.28.2-eksbuild.2"
      resolve_conflicts = "OVERWRITE"
    }
  }

  # Storage Configuration
  enable_ebs_csi_driver = true
  ebs_csi_driver_config = {
    addon_version     = "v1.25.0-eksbuild.2"
    resolve_conflicts = "OVERWRITE"
  }

  enable_efs_csi_driver = true
  efs_csi_driver_config = {
    addon_version     = "v1.7.2-eksbuild.1"
    resolve_conflicts = "OVERWRITE"
  }

  # Logging Configuration
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 90

  # Security Configuration
  cluster_encryption_config = [{
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }]

  # Additional Security Group Rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Node groups to cluster API"
      protocol                  = "tcp"
      from_port                 = 1025
      to_port                   = 65535
      type                      = "ingress"
      source_node_security_group = true
    }
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }

  # AWS Auth Configuration
  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::66666666666:role/role1"
      username = "role1"
      groups   = ["system:masters"]
    }
  ]

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::66666666666:user/user1"
      username = "user1"
      groups   = ["system:masters"]
    }
  ]

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}

# KMS key for cluster encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/eks-key"
  target_key_id = aws_kms_key.eks.key_id
}
