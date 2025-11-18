terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "ECommerce-Cloud-Assignment"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr            = var.vpc_cidr
  availability_zones  = slice(data.aws_availability_zones.available.names, 0, 2)
  project_name        = var.project_name
}

# EKS Module
module "eks" {
  source = "./modules/eks"
  
  cluster_name        = "${var.project_name}-cluster"
  cluster_version     = "1.28"
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = ["t3.medium"]
  desired_size        = 2
  min_size            = 2
  max_size            = 4
}

# RDS Module
module "rds" {
  source = "./modules/rds"
  
  db_name             = "ecommercedb"
  db_username         = var.db_username
  db_password         = var.db_password
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  eks_security_group_id = module.eks.cluster_security_group_id
}

# DynamoDB
resource "aws_dynamodb_table" "products" {
  name           = "ecommerce-products"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "product_id"
  
  attribute {
    name = "product_id"
    type = "S"
  }
  
  attribute {
    name = "category"
    type = "S"
  }
  
  global_secondary_index {
    name            = "CategoryIndex"
    hash_key        = "category"
    projection_type = "ALL"
  }
  
  tags = {
    Name = "ecommerce-products"
  }
}

# S3 Bucket
resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.project_name}-data-bucket-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name = "ecommerce-data-bucket"
  }
}

resource "aws_s3_bucket_versioning" "data_bucket_versioning" {
  bucket = aws_s3_bucket.data_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.data_bucket.id
  
  lambda_function {
    lambda_function_arn = module.lambda.function_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }
  
  depends_on = [module.lambda]
}

# MSK (Kafka) Module
module "msk" {
  source = "./modules/msk"
  
  cluster_name       = "${var.project_name}-kafka"
  kafka_version      = "3.5.1"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  eks_security_group_id = module.eks.cluster_security_group_id
}

# Lambda Module
module "lambda" {
  source = "./modules/lambda"
  
  function_name      = "s3-file-processor"
  s3_bucket_name     = aws_s3_bucket.data_bucket.id
  s3_bucket_arn      = aws_s3_bucket.data_bucket.arn
}

# ECR Repositories
resource "aws_ecr_repository" "microservices" {
  for_each = toset([
    "api-gateway",
    "user-service",
    "product-service",
    "order-service",
    "notification-service"
  ])
  
  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = {
    Name = each.key
  }
}

# Outputs
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.products.name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.data_bucket.id
}

output "msk_bootstrap_servers" {
  value       = module.msk.bootstrap_brokers
  description = "MSK Kafka bootstrap servers"
}

output "msk_bootstrap_brokers" {
  value = module.msk.bootstrap_brokers
}

output "lambda_function_name" {
  value = module.lambda.function_name
}

output "ecr_repositories" {
  value = { for k, v in aws_ecr_repository.microservices : k => v.repository_url }
}

output "aws_account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "AWS Account ID"
}

output "aws_region" {
  value       = var.aws_region
  description = "AWS Region"
}
