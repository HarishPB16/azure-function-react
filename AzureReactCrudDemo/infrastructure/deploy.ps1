[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ResourceGroup,
  [Parameter(Mandatory = $true)][string]$Location,
  [Parameter(Mandatory = $true)][string]$StorageAccount,
  [Parameter(Mandatory = $true)][string]$FunctionApp,
  [Parameter(Mandatory = $true)][string]$PostgresServer,
  [string]$PostgresDb = 'cruddb',
  [Parameter(Mandatory = $true)][string]$PostgresUser,
  [Parameter(Mandatory = $true)][string]$PostgresPassword
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$backend = Join-Path $root 'backend/AzureReactCrudFunction'
$frontend = Join-Path $root 'frontend'

az group create --name $ResourceGroup --location $Location | Out-Null
az storage account create --name $StorageAccount --resource-group $ResourceGroup --location $Location --sku Standard_LRS --kind StorageV2 | Out-Null
$storageKey = az storage account keys list --resource-group $ResourceGroup --account-name $StorageAccount --query '[0].value' -o tsv
az storage blob service-properties update --account-name $StorageAccount --account-key $storageKey --static-website --index-document index.html --404-document index.html | Out-Null
$siteUrl = az storage account show --name $StorageAccount --resource-group $ResourceGroup --query 'primaryEndpoints.web' -o tsv

az postgres flexible-server create --resource-group $ResourceGroup --name $PostgresServer --location $Location --admin-user $PostgresUser --admin-password $PostgresPassword --sku-name Standard_B1ms --tier Burstable --public-access 0.0.0.0 | Out-Null
az postgres flexible-server db create --resource-group $ResourceGroup --server-name $PostgresServer --database-name $PostgresDb | Out-Null
$myIp = (Invoke-RestMethod -Uri 'https://api.ipify.org')
az postgres flexible-server firewall-rule create --resource-group $ResourceGroup --name $PostgresServer --rule-name AllowDeploymentClient --start-ip-address $myIp --end-ip-address $myIp | Out-Null

$psql = Get-Command psql -ErrorAction SilentlyContinue
if ($psql) {
  $env:PGPASSWORD = $PostgresPassword
  & $psql.Source "host=$PostgresServer.postgres.database.azure.com port=5432 dbname=$PostgresDb user=$PostgresUser sslmode=require" -f (Join-Path $root 'database/schema.sql')
  Remove-Item Env:PGPASSWORD
} else {
  Write-Warning 'psql is not installed. Run database/schema.sql against the new server before using the API.'
}

az functionapp create --name $FunctionApp --resource-group $ResourceGroup --storage-account $StorageAccount --consumption-plan-location $Location --runtime dotnet-isolated --runtime-version 8.0 --functions-version 4 | Out-Null
$connectionString = "Host=$PostgresServer.postgres.database.azure.com;Port=5432;Database=$PostgresDb;Username=$PostgresUser;Password=$PostgresPassword;SSL Mode=Require"
az functionapp config appsettings set --name $FunctionApp --resource-group $ResourceGroup --settings "ConnectionStrings__Postgres=$connectionString" | Out-Null
az functionapp cors add --name $FunctionApp --resource-group $ResourceGroup --allowed-origins $siteUrl | Out-Null

Push-Location $backend
dotnet publish --configuration Release --output ./publish
Compress-Archive -Path ./publish/* -DestinationPath ./function.zip -Force
az functionapp deployment source config-zip --name $FunctionApp --resource-group $ResourceGroup --src ./function.zip | Out-Null
Pop-Location

Push-Location $frontend
$env:VITE_API_BASE_URL = "https://$FunctionApp.azurewebsites.net/api"
npm ci
npm run build
az storage blob upload-batch --account-name $StorageAccount --account-key $storageKey --destination '$web' --source ./dist --overwrite | Out-Null
Pop-Location

Write-Host "React site: $siteUrl"
Write-Host "Function API: https://$FunctionApp.azurewebsites.net/api/products"
