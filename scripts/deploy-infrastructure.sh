#!/usr/bin/env bash
# deploy-infrastructure.sh
# Orchestrates the two-phase infra deployment (Terraform + EKS ALB dependency).
set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"
CLUSTER_NAME="starttech-cluster"
REGION="${AWS_REGION:-us-east-1}"

echo "=== Phase 1: Provision VPC, EKS, S3, ECR, ElastiCache (placeholder ALB) ==="
cd "$TF_DIR"
terraform init -upgrade
terraform fmt -recursive
terraform validate
terraform apply -auto-approve

echo "=== Configuring kubectl for the new EKS cluster ==="
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

echo "=== Installing AWS Load Balancer Controller (prerequisite for k8s Ingress) ==="
echo "NOTE: Requires the controller's IAM policy/service account to already exist."
echo "See: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html"
helm repo add eks https://aws.github.io/eks-charts || true
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$REGION" \
  --set vpcId="$(terraform output -raw vpc_id)"

echo "=== Apply application Ingress from starttech-application repo to create the ALB ==="
echo "Run this from the starttech-application repo checkout:"
echo "  kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml -f k8s/ingress.yaml"
echo ""
echo "Then fetch the ALB hostname with:"
echo "  kubectl get ingress backend-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo ""
echo "=== Phase 2: update terraform.tfvars with the real alb_dns_name, then re-run: ==="
echo "  terraform apply -auto-approve"