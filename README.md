# AWS EKS Enterprise Wrapper Module

This Terraform module creates a production-ready Amazon EKS cluster with managed node groups, essential addons, and enterprise-grade configurations.

## Features

- Managed Node Groups across multiple availability zones
- VPC CNI, CoreDNS, and kube-proxy addons
- EBS and EFS CSI drivers for persistent storage
- Comprehensive logging and monitoring setup
- Enhanced security configurations with KMS encryption
- IAM roles and security group management
- AWS Auth configuration for RBAC

## Prerequisites

- Terraform >= 1.0
- AWS Provider = 5.83.0
- Kubernetes Provider = 2.20.0
- TLS Provider = 4.0.0
- An existing VPC with private and public subnets
- AWS CLI configured with appropriate credentials

## Initial Setup

### Initializing Submodules

This module uses Git submodules to manage its dependencies. After cloning the repository, you need to initialize and update the submodules:

```bash
# If you haven't cloned the repository yet
git clone <repository-url>
cd eks-enterprise-wrapper

# Initialize and update submodules
git submodule init
git submodule update

# Alternatively, you can clone and initialize submodules in one command
git clone --recurse-submodules <repository-url>
```

The module uses a `.gitmodules` file to track the submodules and their versions:

```ini
[submodule "modules/terraform-aws-eks"]
    path = modules/terraform-aws-eks
    url = https://github.com/terraform-aws-modules/terraform-aws-eks.git
    branch = v20.33.1

[submodule "modules/terraform-aws-eks-ebs-csi-driver"]
    path = modules/terraform-aws-eks-ebs-csi-driver
    url = https://github.com/lablabs/terraform-aws-eks-ebs-csi-driver.git
    branch = v2.10.1

[submodule "modules/terraform-aws-eks-efs-csi-driver"]
    path = modules/terraform-aws-eks-efs-csi-driver
    url = https://github.com/lablabs/terraform-aws-eks-efs-csi-driver.git
    branch = v2.2.7
```

This ensures that specific versions of the modules are used, providing consistency and stability.

## Module Versions

This module uses the following local module versions:

- EKS Module: v20.33.1
- EFS CSI Driver: v2.2.7 (Helm chart version)
- EBS CSI Driver: v2.10.1 (Helm chart version)

All modules are included locally in the `modules/` directory for version stability and offline access.

## Addon Versions

The following addon versions are tested and supported with EKS 1.28:

- VPC CNI: v1.15.4-eksbuild.1
- CoreDNS: v1.11.1-eksbuild.4
- kube-proxy: v1.28.2-eksbuild.2
- EBS CSI Driver: v1.25.0-eksbuild.2
- EFS CSI Driver: v1.7.2-eksbuild.1

## Usage

### Basic Example

```hcl
module "eks" {
  source = "../../"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.28"
  region          = "us-west-2"

  vpc_id     = "vpc-xxxxx"
  subnet_ids = ["subnet-xxxxx", "subnet-yyyyy", "subnet-zzzzz"]

  managed_node_groups = {
    general = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      min_size      = 1
      max_size      = 3
      desired_size  = 1
      disk_size     = 50
      labels        = { role = "general" }
      taints        = []
    }
  }

  # Enable required addons with latest versions
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

  # Enable storage drivers
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

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}
```

See the [examples/complete](./examples/complete) directory for a comprehensive example including:
- Multiple node groups configuration
- All addon configurations
- Storage drivers setup
- Security configurations
- Logging setup
- IAM and RBAC configuration

## Node Groups

The module supports multiple managed node groups with different configurations:

- Instance types and capacity types (ON_DEMAND/SPOT)
- Auto-scaling configuration
- Custom labels and taints
- Disk size and type
- Subnet placement

Example node group configuration:
```hcl
managed_node_groups = {
  general = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    min_size      = 1
    max_size      = 3
    desired_size  = 1
    disk_size     = 50
    labels        = { role = "general" }
    taints        = []
  }
  apps = {
    instance_types = ["t3.large"]
    capacity_type  = "SPOT"
    min_size      = 1
    max_size      = 5
    desired_size  = 2
    disk_size     = 50
    labels        = { role = "apps" }
    taints        = []
  }
}
```

## Storage Options

### EBS CSI Driver
- Enables dynamic provisioning of EBS volumes
- Supports different volume types (gp2, gp3, io1, etc.)
- Automatic volume encryption
- Version: v2.10.1 (Helm chart)
- Addon Version: v1.25.0-eksbuild.2

### EFS CSI Driver
- Provides shared file system storage
- Supports ReadWriteMany access mode
- Ideal for shared storage requirements
- Version: v2.2.7 (Helm chart)
- Addon Version: v1.7.2-eksbuild.1

## Security Features

- KMS encryption for secrets
- Security group management
- IAM roles and policies
- RBAC configuration through aws-auth ConfigMap

Example security configuration:
```hcl
cluster_encryption_config = [{
  provider_key_arn = aws_kms_key.eks.arn
  resources        = ["secrets"]
}]

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
```

## Logging and Monitoring

- Control plane logging to CloudWatch
- Configurable log retention
- Support for all EKS log types:
  - API server
  - Audit
  - Authenticator
  - Controller manager
  - Scheduler

Example logging configuration:
```hcl
cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
cloudwatch_log_group_retention_in_days = 90
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name of the EKS cluster | string | - | yes |
| cluster_version | Kubernetes version | string | "1.28" | no |
| region | AWS region | string | - | yes |
| vpc_id | VPC ID | string | - | yes |
| subnet_ids | Subnet IDs | list(string) | - | yes |
| managed_node_groups | Node groups configuration | map(any) | {} | no |
| cluster_addons | Cluster addons configuration | map(any) | {} | no |
| enable_ebs_csi_driver | Enable EBS CSI driver | bool | true | no |
| enable_efs_csi_driver | Enable EFS CSI driver | bool | false | no |
| cluster_enabled_log_types | List of the desired control plane logging to enable | list(string) | [] | no |
| cloudwatch_log_group_retention_in_days | Number of days to retain log events | number | 90 | no |
| cluster_encryption_config | Configuration block with encryption configuration | list(map(string)) | [] | no |
| aws_auth_roles | List of role maps to add to the aws-auth configmap | list(map(string)) | [] | no |
| aws_auth_users | List of user maps to add to the aws-auth configmap | list(map(string)) | [] | no |
| tags | A map of tags to add to all resources | map(string) | {} | no |

For a complete list of inputs, see [variables.tf](./variables.tf).

## Outputs

| Name | Description |
|------|-------------|
| cluster_arn | The Amazon Resource Name (ARN) of the cluster |
| cluster_endpoint | Endpoint for the Kubernetes API server |
| cluster_id | The name/id of the EKS cluster |
| cluster_security_group_id | ID of the cluster security group |
| node_security_group_id | ID of the node shared security group |
| cluster_oidc_issuer_url | The URL on the EKS cluster for the OpenID Connect identity provider |
| oidc_provider_arn | The ARN of the OIDC Provider |
| cluster_certificate_authority_data | Base64 encoded certificate data required to communicate with the cluster |
| cloudwatch_log_group_name | Name of cloudwatch log group created |
| cloudwatch_log_group_arn | ARN of cloudwatch log group created |

For a complete list of outputs, see [outputs.tf](./outputs.tf).
