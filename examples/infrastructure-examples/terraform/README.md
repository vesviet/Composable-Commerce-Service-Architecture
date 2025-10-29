# Terraform Infrastructure as Code

## Overview
This directory contains Terraform configurations for provisioning cloud infrastructure for the e-commerce microservices platform across AWS, Azure, and GCP.

## Structure
```
terraform/
├── aws/
│   ├── main.tf                    # Main AWS configuration
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values
│   ├── versions.tf                # Provider versions
│   ├── modules/
│   │   ├── eks/                   # EKS cluster module
│   │   ├── rds/                   # RDS databases module
│   │   ├── elasticache/           # Redis cluster module
│   │   ├── msk/                   # Kafka cluster module
│   │   └── monitoring/            # CloudWatch/Prometheus module
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── production/
├── azure/
│   ├── main.tf                    # Main Azure configuration
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── aks/                   # AKS cluster module
│       ├── postgresql/            # Azure Database module
│       └── servicebus/            # Service Bus module
├── gcp/
│   ├── main.tf                    # Main GCP configuration
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── gke/                   # GKE cluster module
│       ├── cloudsql/              # Cloud SQL module
│       └── pubsub/                # Pub/Sub module
└── shared/
    ├── modules/
    │   ├── networking/            # VPC/Network module
    │   ├── security/              # Security groups/policies
    │   └── monitoring/            # Monitoring stack
    └── scripts/
        ├── init.sh                # Terraform initialization
        └── deploy.sh              # Deployment script
```

## AWS Infrastructure

### Main Configuration (aws/main.tf)
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }

  backend "s3" {
    bucket         = "ecommerce-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "ecommerce-microservices"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC and Networking
module "vpc" {
  source = "./modules/networking"
  
  name               = "${var.project_name}-${var.environment}"
  cidr               = var.vpc_cidr
  availability_zones = data.aws_availability_zones.available.names
  
  enable_nat_gateway = true
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support = true
  
  tags = {
    Environment = var.environment
  }
}

# EKS Cluster
module "eks" {
  source = "./modules/eks"
  
  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.kubernetes_version
  
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  
  node_groups = {
    main = {
      desired_capacity = var.eks_node_desired_capacity
      max_capacity     = var.eks_node_max_capacity
      min_capacity     = var.eks_node_min_capacity
      
      instance_types = ["t3.large", "t3.xlarge"]
      capacity_type  = "ON_DEMAND"
      
      k8s_labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }
    }
    
    spot = {
      desired_capacity = 2
      max_capacity     = 10
      min_capacity     = 0
      
      instance_types = ["t3.large", "t3.xlarge", "t3.2xlarge"]
      capacity_type  = "SPOT"
      
      k8s_labels = {
        Environment = var.environment
        NodeGroup   = "spot"
      }
      
      taints = [
        {
          key    = "spot"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }
  
  tags = {
    Environment = var.environment
  }
}

# RDS Databases
module "databases" {
  source = "./modules/rds"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnets
  
  databases = {
    catalog = {
      identifier     = "${var.project_name}-catalog-${var.environment}"
      engine         = "postgres"
      engine_version = "15.3"
      instance_class = "db.t3.micro"
      allocated_storage = 20
      storage_encrypted = true
      
      db_name  = "catalog_db"
      username = "catalog_user"
      
      backup_retention_period = 7
      backup_window          = "03:00-04:00"
      maintenance_window     = "sun:04:00-sun:05:00"
    }
    
    order = {
      identifier     = "${var.project_name}-order-${var.environment}"
      engine         = "postgres"
      engine_version = "15.3"
      instance_class = "db.t3.small"
      allocated_storage = 50
      storage_encrypted = true
      
      db_name  = "order_db"
      username = "order_user"
      
      backup_retention_period = 30
      backup_window          = "03:00-04:00"
      maintenance_window     = "sun:04:00-sun:05:00"
    }
    
    customer = {
      identifier     = "${var.project_name}-customer-${var.environment}"
      engine         = "postgres"
      engine_version = "15.3"
      instance_class = "db.t3.micro"
      allocated_storage = 20
      storage_encrypted = true
      
      db_name  = "customer_db"
      username = "customer_user"
      
      backup_retention_period = 30
      backup_window          = "03:00-04:00"
      maintenance_window     = "sun:04:00-sun:05:00"
    }
  }
  
  tags = {
    Environment = var.environment
  }
}

# ElastiCache Redis
module "redis" {
  source = "./modules/elasticache"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  cluster_id           = "${var.project_name}-redis-${var.environment}"
  node_type           = "cache.t3.micro"
  num_cache_nodes     = 1
  parameter_group_name = "default.redis7"
  port                = 6379
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  tags = {
    Environment = var.environment
  }
}

# MSK Kafka Cluster
module "kafka" {
  source = "./modules/msk"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  cluster_name           = "${var.project_name}-kafka-${var.environment}"
  kafka_version         = "2.8.1"
  number_of_broker_nodes = 3
  instance_type         = "kafka.t3.small"
  
  ebs_volume_size = 100
  
  encryption_in_transit_client_broker = "TLS"
  encryption_in_transit_in_cluster   = true
  
  tags = {
    Environment = var.environment
  }
}

# Elasticsearch
resource "aws_elasticsearch_domain" "main" {
  domain_name           = "${var.project_name}-search-${var.environment}"
  elasticsearch_version = "7.10"
  
  cluster_config {
    instance_type  = "t3.small.elasticsearch"
    instance_count = 3
    
    dedicated_master_enabled = false
    zone_awareness_enabled   = true
    
    zone_awareness_config {
      availability_zone_count = 3
    }
  }
  
  vpc_options {
    subnet_ids = module.vpc.private_subnets
    security_group_ids = [aws_security_group.elasticsearch.id]
  }
  
  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = 20
  }
  
  encrypt_at_rest {
    enabled = true
  }
  
  node_to_node_encryption {
    enabled = true
  }
  
  domain_endpoint_options {
    enforce_https = true
  }
  
  tags = {
    Environment = var.environment
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = module.vpc.public_subnets
  
  enable_deletion_protection = var.environment == "production"
  
  tags = {
    Environment = var.environment
  }
}

# Security Groups
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-${var.environment}"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "${var.project_name}-alb-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_security_group" "elasticsearch" {
  name_prefix = "${var.project_name}-es-${var.environment}"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }
  
  tags = {
    Name        = "${var.project_name}-elasticsearch-${var.environment}"
    Environment = var.environment
  }
}
```

### EKS Module (aws/modules/eks/main.tf)
```hcl
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version
  
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs    = ["0.0.0.0/0"]
  }
  
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }
  
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
    aws_cloudwatch_log_group.cluster,
  ]
  
  tags = var.tags
}

resource "aws_eks_node_group" "main" {
  for_each = var.node_groups
  
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  
  capacity_type  = each.value.capacity_type
  instance_types = each.value.instance_types
  
  scaling_config {
    desired_size = each.value.desired_capacity
    max_size     = each.value.max_capacity
    min_size     = each.value.min_capacity
  }
  
  update_config {
    max_unavailable = 1
  }
  
  labels = each.value.k8s_labels
  
  dynamic "taint" {
    for_each = lookup(each.value, "taints", [])
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
  
  tags = var.tags
}

# IAM Roles
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"
  
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"
  
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# KMS Key for EKS encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  tags = var.tags
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7
  
  tags = var.tags
}

# OIDC Identity Provider
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  
  tags = var.tags
}
```

### Variables (aws/variables.tf)
```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ecommerce"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.27"
}

variable "eks_node_desired_capacity" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 3
}

variable "eks_node_max_capacity" {
  description = "Maximum number of EKS nodes"
  type        = number
  default     = 10
}

variable "eks_node_min_capacity" {
  description = "Minimum number of EKS nodes"
  type        = number
  default     = 1
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "ecommerce.example.com"
}

variable "enable_monitoring" {
  description = "Enable monitoring stack"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable centralized logging"
  type        = bool
  default     = true
}
```

### Outputs (aws/outputs.tf)
```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "eks_cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "database_endpoints" {
  description = "RDS instance endpoints"
  value       = module.databases.db_instance_endpoints
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.redis.cache_nodes[0].address
}

output "kafka_bootstrap_brokers" {
  description = "MSK Kafka bootstrap brokers"
  value       = module.kafka.bootstrap_brokers
}

output "elasticsearch_endpoint" {
  description = "Elasticsearch domain endpoint"
  value       = aws_elasticsearch_domain.main.endpoint
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}
```

## Environment-Specific Configurations

### Production Environment (aws/environments/production/terraform.tfvars)
```hcl
# Environment
environment = "production"
aws_region  = "us-west-2"

# VPC
vpc_cidr = "10.0.0.0/16"

# EKS
kubernetes_version = "1.27"
eks_node_desired_capacity = 6
eks_node_max_capacity = 20
eks_node_min_capacity = 3

# Domain
domain_name = "api.ecommerce.com"

# Features
enable_monitoring = true
enable_logging = true
```

### Development Environment (aws/environments/dev/terraform.tfvars)
```hcl
# Environment
environment = "dev"
aws_region  = "us-west-2"

# VPC
vpc_cidr = "10.1.0.0/16"

# EKS
kubernetes_version = "1.27"
eks_node_desired_capacity = 2
eks_node_max_capacity = 5
eks_node_min_capacity = 1

# Domain
domain_name = "dev-api.ecommerce.com"

# Features
enable_monitoring = true
enable_logging = false
```

## Deployment Scripts

### scripts/init.sh
```bash
#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
CLOUD_PROVIDER=${2:-aws}

echo "🚀 Initializing Terraform for $ENVIRONMENT environment on $CLOUD_PROVIDER"

# Check if required tools are installed
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform is required but not installed."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI is required but not installed."; exit 1; }

# Navigate to the appropriate directory
cd "$CLOUD_PROVIDER/environments/$ENVIRONMENT"

# Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init

# Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📋 Planning Terraform deployment..."
terraform plan -var-file="terraform.tfvars" -out="tfplan"

echo "✅ Terraform initialization complete!"
echo ""
echo "🚀 To apply the plan, run:"
echo "  terraform apply tfplan"
```

### scripts/deploy.sh
```bash
#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
CLOUD_PROVIDER=${2:-aws}
AUTO_APPROVE=${3:-false}

echo "🚀 Deploying infrastructure for $ENVIRONMENT environment on $CLOUD_PROVIDER"

# Navigate to the appropriate directory
cd "$CLOUD_PROVIDER/environments/$ENVIRONMENT"

# Check if plan exists
if [ ! -f "tfplan" ]; then
    echo "❌ No Terraform plan found. Run init.sh first."
    exit 1
fi

# Apply the plan
if [ "$AUTO_APPROVE" = "true" ]; then
    echo "🚀 Applying Terraform plan (auto-approved)..."
    terraform apply -auto-approve tfplan
else
    echo "🚀 Applying Terraform plan..."
    terraform apply tfplan
fi

# Output important information
echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Important outputs:"
terraform output

# Update kubeconfig for EKS
if [ "$CLOUD_PROVIDER" = "aws" ]; then
    CLUSTER_NAME=$(terraform output -raw eks_cluster_id)
    AWS_REGION=$(terraform output -raw aws_region || echo "us-west-2")
    
    echo ""
    echo "🔧 Updating kubeconfig for EKS cluster..."
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
    
    echo "✅ Kubeconfig updated. You can now use kubectl to interact with the cluster."
fi

echo ""
echo "🎉 Infrastructure deployment completed successfully!"
```

## Multi-Cloud Support

### Azure Configuration (azure/main.tf)
```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.azure_region
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.project_name}-${var.environment}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.project_name}-${var.environment}"
  
  default_node_pool {
    name       = "default"
    node_count = var.aks_node_count
    vm_size    = "Standard_D2_v2"
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = {
    Environment = var.environment
  }
}

# Azure Database for PostgreSQL
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.project_name}-${var.environment}-postgres"
  resource_group_name    = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  version               = "13"
  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password
  
  storage_mb = 32768
  sku_name   = "B_Standard_B1ms"
  
  tags = {
    Environment = var.environment
  }
}
```

### GCP Configuration (gcp/main.tf)
```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# GKE Cluster
resource "google_container_cluster" "main" {
  name     = "${var.project_name}-${var.environment}-gke"
  location = var.gcp_region
  
  remove_default_node_pool = true
  initial_node_count       = 1
  
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
  
  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "main" {
  name       = "${var.project_name}-${var.environment}-nodes"
  location   = var.gcp_region
  cluster    = google_container_cluster.main.name
  node_count = var.gke_node_count
  
  node_config {
    preemptible  = false
    machine_type = "e2-medium"
    
    service_account = google_service_account.main.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# Cloud SQL
resource "google_sql_database_instance" "main" {
  name             = "${var.project_name}-${var.environment}-postgres"
  database_version = "POSTGRES_13"
  region          = var.gcp_region
  
  settings {
    tier = "db-f1-micro"
    
    backup_configuration {
      enabled = true
    }
  }
  
  deletion_protection = var.environment == "production"
}
```

## Usage Instructions

### Prerequisites
```bash
# Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
```

### Deployment Process
```bash
# 1. Initialize Terraform
./scripts/init.sh production aws

# 2. Review the plan
cd aws/environments/production
terraform show tfplan

# 3. Deploy infrastructure
cd ../../../
./scripts/deploy.sh production aws

# 4. Verify deployment
kubectl get nodes
kubectl get namespaces
```

### Environment Management
```bash
# Deploy to different environments
./scripts/deploy.sh dev aws
./scripts/deploy.sh staging aws
./scripts/deploy.sh production aws

# Destroy environment (careful!)
cd aws/environments/dev
terraform destroy -var-file="terraform.tfvars"
```

This Terraform configuration provides a complete Infrastructure as Code solution for deploying the e-commerce microservices platform across multiple cloud providers with environment-specific configurations.