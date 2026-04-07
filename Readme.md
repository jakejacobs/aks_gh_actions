# --- VARIABLES ---

RG_NAME="ecommerce-rg"
LOCATION="centralindia"
ACR_NAME="acrghactions123"
AKS_NAME="ecommerce-aks-cluster"

az group create --name $RG_NAME --location $LOCATION
az acr create --resource-group $RG_NAME --name $ACR_NAME --sku Basic

APP_ID=$(az ad app create --display-name github-actions-pipeline --query appId -o tsv)
SP_ID=$(az ad sp create --id $APP_ID --query id -o tsv)

SUB_ID=$(az account show --query id -o tsv)
az role assignment create --assignee $SP_ID --role contributor --scope /subscriptions/$SUB_ID/resourceGroups/$RG_NAME

az ad app federated-credential create --id $APP_ID --parameters '{
"name": "github-actions-trust",
"issuer": "https://token.actions.githubusercontent.com",
"subject": "repo:<github-org>/<repo-name>:ref:refs/heads/main",
"audiences": ["api://AzureADTokenExchange"]
}'

az aks create \
 --resource-group $RG_NAME \
 --name $AKS_NAME \
 --node-count 1 \
 --generate-ssh-keys \
 --attach-acr $ACR_NAME

az aks get-credentials --resource-group ecommerce-rg --name ecommerce-aks-cluster

kubectl apply -f k8s/deployment.yaml

kubectl get services -w

az group delete --name ecommerce-rg --yes --no-wait
