variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones for the VPC subnets"
  type        = list(string)

  default = [
    "us-east-1a",
    "us-east-1b"
  ]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "eks_cluster_version" {
  type    = string
  default = "1.34"
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "alb_dns_name" {
  description = <<-EOT
    DNS name of the backend ALB, created by the AWS Load Balancer Controller
    from k8s/ingress.yaml. Use a placeholder for the first `terraform apply`
    (phase 1), then update this value and re-apply (phase 2) once the real
    ALB exists. Retrieve it with:
      kubectl get ingress backend-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
  EOT
  type        = string
  default     = "placeholder-alb.us-east-1.elb.amazonaws.com"
}
