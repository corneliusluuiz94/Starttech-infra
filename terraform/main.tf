terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }

  # Recommended: use a remote backend for team collaboration / CI.
  # backend "s3" {
  #   bucket         = "starttech-terraform-state"
  #   key            = "starttech/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "starttech-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}

# ---------------- Networking ----------------
module "networking" {
  source = "./modules/networking"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# ---------------- EKS ----------------
module "eks" {
  source = "./modules/eks"

  vpc_id             = module.networking.vpc_id
  cluster_version    = var.eks_cluster_version
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids

  node_desired_size = var.node_desired_size
  node_min_size     = var.node_min_size
  node_max_size     = var.node_max_size
}

# ---------------- Storage (S3 + ECR) ----------------
module "storage" {
  source = "./modules/storage"

  environment = var.environment
}

# ---------------- CDN (unified CloudFront: S3-Frontend + ALB-Backend) ----------------
# NOTE: alb_dns_name is only known once the AWS Load Balancer Controller (installed
# via kubectl after the EKS cluster + k8s/ingress.yaml are applied) has provisioned
# the ALB. This is a two-phase deploy -- see scripts/deploy-infrastructure.sh and the
# README for the exact sequencing. Until phase 2, var.alb_dns_name may be a placeholder.
module "cdn" {
  source = "./modules/cdn"

  s3_bucket_regional_domain_name = module.storage.bucket_regional_domain_name
  alb_dns_name                   = var.alb_dns_name
}

# ---------------- Bucket policy granting CloudFront (OAC) read access ----------------
# Placed in root, not in the storage module, to avoid a module-to-module circular
# dependency (S3 policy needs the CloudFront ARN; CloudFront needs the S3 bucket).
resource "aws_s3_bucket_policy" "starttech-frontend-bucket-policy" {
  bucket = module.storage.bucket_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontServicePrincipalReadOnly"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${module.storage.bucket_arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = module.cdn.distribution_arn
        }
      }
    }]
  })
}

# ---------------- Database (ElastiCache Redis) ----------------
module "database" {
  source = "./modules/database"

  vpc_id                     = module.networking.vpc_id
  private_subnet_ids         = module.networking.private_subnet_ids
  eks_node_security_group_id = module.eks.cluster_security_group_id
}
