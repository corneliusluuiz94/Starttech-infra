output "vpc_id" {
  value = module.networking.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "frontend_bucket_name" {
  value = module.storage.bucket_id
}

output "ecr_repository_url" {
  value = module.storage.ecr_repository_url
}

output "cloudfront_distribution_id" {
  value = module.cdn.distribution_id
}

output "cloudfront_domain_name" {
  description = "The single unified HTTPS domain for both frontend and /api/* traffic"
  value       = module.cdn.distribution_domain_name
}

output "redis_endpoint" {
  value = module.database.redis_primary_endpoint
}
