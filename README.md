# starttech-infra

Terraform infrastructure-as-code for StartTech's production platform: VPC, Amazon EKS,
S3 + CloudFront (unified frontend/API reverse proxy), ECR, and ElastiCache Redis.

## Architecture

```
                        ┌─────────────────────────────┐
                        │   CloudFront (single dist.)  │
   Browser  ───HTTPS──▶ │  default(*)  → S3-Frontend   │
                        │  /api/*      → ALB-Backend    │
                        └───────┬───────────┬───────────┘
                                │           │
                     OAC        │           │  HTTP (internal)
                                ▼           ▼
                        ┌───────────┐  ┌──────────────┐
                        │  S3 (React)│  │  ALB → EKS    │
                        └───────────┘  │  (Golang API) │
                                        └──────┬────────┘
                                               │
                                   ┌───────────┴───────────┐
                                   ▼                        ▼
                          ElastiCache Redis          MongoDB Atlas (external)
```

This design solves two classic SPA deployment problems:
1. **Client-side routing 403/404s** — CloudFront custom error responses rewrite
   403/404 from S3 to `/index.html` with a `200`, so React Router can take over.
2. **Mixed content blocking** — a single CloudFront distribution fronts both the S3
   bucket (`S3-Frontend`) and the backend ALB (`ALB-Backend`) over HTTPS, so the
   frontend can call `/api/v1/...` with relative paths and never hit an `http://` URL.

## Directory Structure

```
terraform/
├── main.tf                    # Root module wiring
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
└── modules/
    ├── networking/             # VPC, public/private subnets, NAT, IGW
    ├── eks/                    # EKS cluster, managed node group, IAM roles
    ├── storage/                # S3 static hosting bucket, ECR repo
    ├── cdn/                    # Unified CloudFront distribution
    └── database/               # ElastiCache Redis
```

## Two-Phase Deployment (important)

The CloudFront `ALB-Backend` origin needs the ALB's DNS name. That ALB is created by
the **AWS Load Balancer Controller** from `k8s/ingress.yaml` in `starttech-application`
— i.e., *after* the EKS cluster exists. So deployment is two phases:

1. **Phase 1** — `terraform apply` with a placeholder `alb_dns_name` to create the VPC,
   EKS cluster/node group, S3 bucket, ECR repo, ElastiCache, and CloudFront (with a
   dummy ALB origin).
2. Install the AWS Load Balancer Controller, then `kubectl apply -f k8s/` from
   `starttech-application` to provision the real ALB via the Ingress resource.
3. **Phase 2** — Update `alb_dns_name` in `terraform.tfvars` with the real ALB
   hostname (`kubectl get ingress ... -o jsonpath=...`) and re-run `terraform apply`.

`scripts/deploy-infrastructure.sh` automates this sequence.

## Prerequisites

- Terraform >= 1.6
- AWS CLI v2, configured credentials with permissions to create VPC/EKS/S3/CloudFront/ECR/ElastiCache/IAM
- `kubectl` and `helm` for the Load Balancer Controller install

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars as needed
terraform init
terraform fmt -check -recursive
terraform validate
terraform apply
```

Or run the whole two-phase flow: `./scripts/deploy-infrastructure.sh`

## Naming Conventions (grading-critical)

| Resource | Identifier |
|---|---|
| VPC | `starttech-vpc` |
| EKS Cluster | `starttech-cluster` |
| EKS Node Group | `starttech-node-group` |
| S3 Bucket | `starttech-frontend-bucket-*` |
| ElastiCache Redis | `starttech-redis` |
| ECR Repo | `starttech-backend-api` |
| CloudFront S3 Origin ID | `S3-Frontend` |
| CloudFront ALB Origin ID | `ALB-Backend` |
| Container target port | `8080` |

## CI/CD

`.github/workflows/infrastructure-deploy.yml` triggers on pushes to `main` touching
`terraform/**`, and runs `terraform fmt -check`, `terraform validate`, `terraform plan`,
and `terraform apply -auto-approve`.

Required repository secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (and optional
repo/org variable `AWS_REGION`).

## Grader IAM User

Create a read-only IAM user `start-tech-grader` and attach the least-privilege policy
documented in the assessment (S3 list/public-access-block, CloudFront list/get-config,
EKS describe, ElastiCache describe). Do not grant write access.
