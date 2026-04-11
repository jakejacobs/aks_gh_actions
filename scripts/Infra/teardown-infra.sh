#!/bin/bash

# Hit the emergency brake if a command fails
set -e 

echo "INFRASTRUCTURE TEARDOWN"

# --- 1. PRE-FLIGHT CHECK ---
if ! az account show > /dev/null 2>&1; then
  echo "ERROR: You are not logged into Azure. Please run 'az login' first."
  exit 1
fi

# --- 2. LIST CURRENT RESOURCES ---
echo "Here are the Resource Groups currently in your Azure account:"
echo "--------------------------------------------------------"
az group list --query "[].{Name:name, Location:location}" -o table
echo "--------------------------------------------------------"
echo "NOTE: The 'MC_ecommerce-rg...' group is a managed K8s resource."
echo "It will be automatically destroyed when 'ecommerce-rg' is deleted."
echo ""

# --- 3. INTERACTIVE CONFIRMATION ---
read -p "Are you absolutely sure you want to permanently delete these resources AND your GitHub robot account? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Teardown aborted. Your infrastructure is safe."
  exit 0
fi

echo ""
echo "Starting teardown process..."

# --- 4. CLEAN UP SECURITY IDENTITIES ---
APP_NAME="github-actions-pipeline"
echo "Looking for App Registration: $APP_NAME..."
APP_ID=$(az ad app list --display-name $APP_NAME --query "[0].appId" -o tsv)

if [ -n "$APP_ID" ]; then
    echo "Deleting App Registration ($APP_ID)..."
    az ad app delete --id $APP_ID
else
    echo "App Registration not found. Skipping."
fi

# --- 5. CLEAN UP INFRASTRUCTURE ---
echo "Initiating deletion of Resource Group: ecommerce-rg (This will also destroy the MC_ group)..."
# We use --no-wait so your terminal doesn't freeze for 15 minutes while Azure deletes the hardware
az group delete --name ecommerce-rg --yes --no-wait

echo "Initiating deletion of Resource Group: NetworkWatcherRG..."
az group delete --name NetworkWatcherRG --yes --no-wait

echo ""
echo "TEARDOWN INITIATED SUCCESSFULLY!"
echo "Azure is currently destroying the hardware in the background."
echo "It usually takes 10-15 minutes for the resource groups to completely disappear from your portal."