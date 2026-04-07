# Setup Azure Cloud and cli

https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively?view=azure-cli-latest

# Setup Azure Container Registry and Resource Group for GitHub Actions

## 1. Set up variables (Ensure ACR name is globally unique and all lowercase/numbers)

RG_NAME="acr-rg"
LOCATION="centralindia"
ACR_NAME="acrghactions123"

## 2. Create the Resource Group

az group create --name $RG_NAME --location $LOCATION

## 3. Create the Azure Container Registry

az acr create --resource-group $RG_NAME --name $ACR_NAME --sku Basic

---

# Create the Azure Identity

## Create the App Registration

APP_ID=$(az ad app create --display-name github-actions-pipeline --query appId -o tsv)

## Create a Service Principal for it (gives it physical presence in our Azure tenant)

SP_ID=$(az ad sp create --id $APP_ID --query id -o tsv)

## Give this identity permission to modify our Resource Group

SUB_ID=$(az account show --query id -o tsv)
az role assignment create --assignee $SP_ID --role contributor --scope /subscriptions/$SUB_ID/resourceGroups/$RG_NAME

---

# Link this Azure Identity to the GitHub repo (Federation)

az ad app federated-credential create --id $APP_ID --parameters '{
"name": "github-actions-trust",
"issuer": "https://token.actions.githubusercontent.com",
"subject": "repo:<github-org>/<repo-name>:ref:refs/heads/main",
"description": "Trust GitHub Actions main branch",
"audiences": ["api://AzureADTokenExchange"]
}'

---

# Store the App ID in GitHub Secrets

AZURE_CLIENT_ID=$APP_ID
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
AZURE_SUBSCRIPTION_ID=$SUB_ID

---

# Enable the "Admin User" on your ACR and get password

az acr update --name $ACR_NAME --admin-enabled true

az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv

---

# Create k8s secret for ACR pull

kubectl create secret docker-registry my-acr-secret \
 --docker-server=$ACR_NAME.azurecr.io \
 --docker-username=$ACR_NAME \
 --docker-password=<paste-the-password-here>

# Delete the Infrastructure when done

az group delete --name acr-rg --yes --no-wait
az ad app delete --id $APP_ID
