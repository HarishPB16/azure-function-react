#!/usr/bin/env bash
set -euo pipefail
: "${RESOURCE_GROUP:?Set RESOURCE_GROUP}"
: "${LOCATION:?Set LOCATION}"
: "${STORAGE_ACCOUNT:?Set STORAGE_ACCOUNT}"
: "${FUNCTION_APP:?Set FUNCTION_APP}"
: "${POSTGRES_SERVER:?Set POSTGRES_SERVER}"
: "${POSTGRES_USER:?Set POSTGRES_USER}"
: "${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD}"
POSTGRES_DB="${POSTGRES_DB:-cruddb}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
az group create -n "$RESOURCE_GROUP" -l "$LOCATION" >/dev/null
az storage account create -n "$STORAGE_ACCOUNT" -g "$RESOURCE_GROUP" -l "$LOCATION" --sku Standard_LRS --kind StorageV2 >/dev/null
KEY="$(az storage account keys list -g "$RESOURCE_GROUP" -n "$STORAGE_ACCOUNT" --query '[0].value' -o tsv)"
az storage blob service-properties update --account-name "$STORAGE_ACCOUNT" --account-key "$KEY" --static-website --index-document index.html --404-document index.html >/dev/null
SITE_URL="$(az storage account show -g "$RESOURCE_GROUP" -n "$STORAGE_ACCOUNT" --query primaryEndpoints.web -o tsv)"
az postgres flexible-server create -g "$RESOURCE_GROUP" -n "$POSTGRES_SERVER" -l "$LOCATION" --admin-user "$POSTGRES_USER" --admin-password "$POSTGRES_PASSWORD" --sku-name Standard_B1ms --tier Burstable --public-access 0.0.0.0 >/dev/null
az postgres flexible-server db create -g "$RESOURCE_GROUP" -s "$POSTGRES_SERVER" -d "$POSTGRES_DB" >/dev/null
MY_IP="$(curl -s https://api.ipify.org)"; az postgres flexible-server firewall-rule create -g "$RESOURCE_GROUP" -n "$POSTGRES_SERVER" --rule-name AllowDeploymentClient --start-ip-address "$MY_IP" --end-ip-address "$MY_IP" >/dev/null
if command -v psql >/dev/null; then PGPASSWORD="$POSTGRES_PASSWORD" psql "host=$POSTGRES_SERVER.postgres.database.azure.com port=5432 dbname=$POSTGRES_DB user=$POSTGRES_USER sslmode=require" -f "$ROOT/database/schema.sql"; else echo 'WARNING: psql missing; run database/schema.sql manually.' >&2; fi
az functionapp create -n "$FUNCTION_APP" -g "$RESOURCE_GROUP" --storage-account "$STORAGE_ACCOUNT" --consumption-plan-location "$LOCATION" --runtime dotnet-isolated --runtime-version 8.0 --functions-version 4 >/dev/null
CONNECTION="Host=$POSTGRES_SERVER.postgres.database.azure.com;Port=5432;Database=$POSTGRES_DB;Username=$POSTGRES_USER;Password=$POSTGRES_PASSWORD;SSL Mode=Require"
az functionapp config appsettings set -g "$RESOURCE_GROUP" -n "$FUNCTION_APP" --settings "ConnectionStrings__Postgres=$CONNECTION" >/dev/null
az functionapp cors add -g "$RESOURCE_GROUP" -n "$FUNCTION_APP" --allowed-origins "$SITE_URL" >/dev/null
(cd "$ROOT/backend/AzureReactCrudFunction" && dotnet publish -c Release -o publish && (cd publish && zip -r ../function.zip .) && az functionapp deployment source config-zip -g "$RESOURCE_GROUP" -n "$FUNCTION_APP" --src function.zip)
(cd "$ROOT/frontend" && VITE_API_BASE_URL="https://$FUNCTION_APP.azurewebsites.net/api" npm ci && VITE_API_BASE_URL="https://$FUNCTION_APP.azurewebsites.net/api" npm run build && az storage blob upload-batch --account-name "$STORAGE_ACCOUNT" --account-key "$KEY" --destination '$web' --source dist --overwrite)
echo "React site: $SITE_URL"; echo "Function API: https://$FUNCTION_APP.azurewebsites.net/api/products"
