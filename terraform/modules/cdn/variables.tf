variable "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 frontend bucket"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the backend Application Load Balancer"
  type        = string
}
