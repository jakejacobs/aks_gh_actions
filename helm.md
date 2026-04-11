# Ingress-Nginx Helm Chart

## Docs

https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx

---

## Commands

## Get Repo Info

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

## Install Chart

helm install [RELEASE_NAME] ingress-nginx/ingress-nginx

## Uninstall Chart

helm uninstall [RELEASE_NAME]

## Upgrading Chart

helm upgrade [RELEASE_NAME] [CHART] --install

## Configuration

helm show values ingress-nginx/ingress-nginx
