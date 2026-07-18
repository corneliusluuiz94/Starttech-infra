variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (ALB, NAT Gateways)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (EKS nodes, ElastiCache)"
  type        = list(string)

}
variable "availability_zones" {
  description = "Availability Zones for the VPC"
  type        = list(string)
}