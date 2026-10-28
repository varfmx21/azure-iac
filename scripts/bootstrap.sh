#!/usr/bin/env bash
# One-time bootstrap (run locally after `az login`).
# Creates what Terraform cannot create for itself:
#  1) a storage account for the Terraform state
#  2) an Entra ID app + federated credentials so GitHub Actions logs in without a stored password (OIDC)
set -euo pipefail
: "${GITHUB_REPO:?Set GITHUB_REPO=owner/this-iac-repo}"
LOCATION="${LOCATION:-westeurope}"
STATE_RG="rg-forgetask-tfstate"
STATE_SA="sttfstate${RANDOM}${RANDOM}"

SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

az group create -n "$STATE_RG" -l "$LOCATION" -o none
az storage account create -n "$STATE_SA" -g "$STATE_RG" -l "$LOCATION" \
  --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false -o none
SA_ID=$(az storage account show -n "$STATE_SA" -g "$STATE_RG" --query id -o tsv)
az storage container create -n tfstate --account-name "$STATE_SA" --auth-mode key -o none

APP_ID=$(az ad app create --display-name "forgetask-iac-gha" --query appId -o tsv)
az ad sp create --id "$APP_ID" -o none
SP_OID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

for SUBJECT in "ref:refs/heads/main" "pull_request"; do
  NAME="gha-$(echo "$SUBJECT" | tr ':/' '--')"
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"$NAME\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_REPO}:${SUBJECT}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]}" -o none
done

# Baseline = broad rights on purpose (reduced later with least privilege).
for ROLE in "Contributor" "User Access Administrator"; do
  az role assignment create --assignee-object-id "$SP_OID" --assignee-principal-type ServicePrincipal \
    --role "$ROLE" --scope "/subscriptions/$SUB_ID" -o none
done
az role assignment create --assignee-object-id "$SP_OID" --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" --scope "$SA_ID" -o none

echo
echo "Create these GitHub repository SECRETS in $GITHUB_REPO:"
echo "  AZURE_CLIENT_ID       = $APP_ID"
echo "  AZURE_TENANT_ID       = $TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID = $SUB_ID"
echo "  TFSTATE_RG            = $STATE_RG"
echo "  TFSTATE_SA            = $STATE_SA"
