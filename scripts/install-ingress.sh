#!/bin/bash
echo "1. Adding the NGINX Helm repository..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

echo "2. Installing the NGINX Ingress Controller into AKS..."
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-basic \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz

echo "Waiting for Azure to assign the Master Public IP..."
kubectl get services -n ingress-basic -w