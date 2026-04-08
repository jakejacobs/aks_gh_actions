#!/bin/bash


# If any single command fails, stop the script immediately. 
set -e 

echo "    PROVISIONING AZURE INFRASTRUCTURE   "

# --- 1. PRE-FLIGHT CHECK: AZURE LOGIN ---
echo "[Check] Verifying Azure CLI login status..."
if ! az account show > /dev/null 2>&1; then
  echo "ERROR: You are not logged into Azure. Please run 'az login' first."
  exit 1
fi
echo "Logged in successfully."

# --- 2. INTERACTIVE PROMPTS ---
echo ""
echo "We need your GitHub details to setup passwordless deployment (OIDC)."
read -p "Enter your GitHub Username or Organization: " GH_ORG
read -p "Enter your GitHub Repository Name: " GH_REPO

echo ""
echo "Please confirm your target repository is: repo:${GH_ORG}/${GH_REPO}:ref:refs/heads/main"
read -p "Is this correct? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborting script. Run it again."
  exit 1
fi

# --- VARIABLES ---
RG_NAME="ecommerce-rg"
LOCATION="centralindia"
ACR_NAME="acrghactions123"
AKS_NAME="ecommerce-aks-cluster"
APP_NAME="github-actions-pipeline"

echo ""
# --- 3. RESOURCE GROUP ---
if [ $(az group exists --name $RG_NAME) = false ]; then
    echo "Creating Resource Group: $RG_NAME..."
    az group create --name $RG_NAME --location $LOCATION -o none
else
    echo "Resource Group '$RG_NAME' already exists. Skipping."
fi

# --- 4. ACR ---
# Check if ACR exists by trying to show it. If it fails (null), create it.
ACR_CHECK=$(az acr show --name $ACR_NAME --resource-group $RG_NAME --query id -o tsv 2>/dev/null || echo "")
if [ -z "$ACR_CHECK" ]; then
    echo "Creating Azure Container Registry: $ACR_NAME..."
    az acr create --resource-group $RG_NAME --name $ACR_NAME --sku Basic -o none
else
    echo "ACR '$ACR_NAME' already exists. Skipping."
fi

# --- 5. SERVICE PRINCIPAL ---
echo "Checking for existing App Registration: $APP_NAME..."
APP_ID=$(az ad app list --display-name $APP_NAME --query "[0].appId" -o tsv)

if [ -z "$APP_ID" ]; then
    echo "Creating new App Registration..."
    APP_ID=$(az ad app create --display-name $APP_NAME --query appId -o tsv)
    echo "Creating Service Principal..."
    SP_ID=$(az ad sp create --id $APP_ID --query id -o tsv)
    
    # Wait a few seconds for Entra ID to sync the new SP before assigning roles
    sleep 5
else
    echo "App Registration already exists (App ID: $APP_ID). Skipping."
    SP_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv)
fi

# --- 6. ROLE ASSIGNMENT ---
SUB_ID=$(az account show --query id -o tsv)
echo "Checking Role Assignments for the Service Principal..."
ROLE_CHECK=$(az role assignment list --assignee $SP_ID --role contributor --scope /subscriptions/$SUB_ID/resourceGroups/$RG_NAME --query "[0].id" -o tsv)

if [ -z "$ROLE_CHECK" ]; then
    echo "Assigning 'Contributor' role to the Service Principal for the Resource Group..."
    az role assignment create --assignee $SP_ID --role contributor --scope /subscriptions/$SUB_ID/resourceGroups/$RG_NAME -o none
else
    echo "Role assignment already exists. Skipping."
fi

# --- 7. OIDC FEDERATED CREDENTIALS (CI & CD) ---
echo "Configuring GitHub OIDC Trust for CI (Main Branch)..."
az ad app federated-credential create --id $APP_ID --parameters "{
  \"name\": \"github-actions-trust\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:${GH_ORG}/${GH_REPO}:ref:refs/heads/main\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}" 2>/dev/null || echo "CI federated credential already exists."

echo "Configuring GitHub OIDC Trust for CD (Production Environment)..."
az ad app federated-credential create --id $APP_ID --parameters "{
  \"name\": \"github-actions-trust-production\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:${GH_ORG}/${GH_REPO}:environment:production\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}" 2>/dev/null || echo "CD federated credential already exists."

# --- 8. AKS CLUSTER ---
AKS_CHECK=$(az aks show --name $AKS_NAME --resource-group $RG_NAME --query id -o tsv 2>/dev/null || echo "")
if [ -z "$AKS_CHECK" ]; then
    echo "Creating AKS Cluster: $AKS_NAME (This will take 5-10 minutes)..."
    az aks create \
      --resource-group $RG_NAME \
      --name $AKS_NAME \
      --node-count 1 \
      --generate-ssh-keys \
      --attach-acr $ACR_NAME -o none
else
    echo "AKS Cluster '$AKS_NAME' already exists. Skipping."
fi

# --- 9. GET CREDENTIALS ---
echo "Downloading AKS credentials to your local machine..."
az aks get-credentials --resource-group $RG_NAME --name $AKS_NAME --overwrite-existing

echo ""

echo "INFRASTRUCTURE READY"
echo "IMPORTANT: Make sure these secrets are in your GitHub Repository:"
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUB_ID"
az account show --query tenantId -o tsv | awk '{print "AZURE_TENANT_ID: " $1}'