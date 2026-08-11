# Azure deployment guide

This guide deploys the complete application to Azure:

```text
React/Vite frontend  -> Azure Storage static website
                         |
                         v
                    Azure Function App (.NET 8)
                         |
                         v
              Azure Database for PostgreSQL Flexible Server
```

The repository's `infrastructure/deploy.ps1` script provisions the resources, builds and deploys both applications, configures the Function App, and uploads the frontend. Follow every step below in order.

> This is a development deployment. The script exposes PostgreSQL publicly and temporarily allows your current public IP address through the database firewall. Do not use this configuration unchanged for production; see [Production hardening](#production-hardening).

## 1. Confirm access and install the required tools

You need an active Azure subscription in which you can create resource groups and resources. Install these tools before starting:

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli-windows)
- Node.js 20 or newer and npm
- .NET 8 SDK
- PostgreSQL command-line client (`psql`) -- required to load the database schema automatically

Azure Functions Core Tools is **not** needed by the deployment script, but is useful if you also run the application locally.

Close and reopen PowerShell after installations, then confirm the tools are available:

```powershell
az version
node --version
npm --version
dotnet --version
psql --version
```

`dotnet --version` must start with `8.`. If `psql` is not available, continue with the deployment, but you must complete the manual schema-import step in [Step 7](#7-confirm-the-database-schema-was-loaded).

## 2. Sign in and select the Azure subscription

Open PowerShell and sign in:

```powershell
az login
az account list --output table
az account set --subscription "YOUR-SUBSCRIPTION-NAME-OR-ID"
az account show --output table
```

Verify that the last command displays the subscription that should be billed. If your organization requires it, ask your Azure administrator for permission to create resources before proceeding.

Register the resource providers once per subscription. Running these commands again is safe:

```powershell
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.DBforPostgreSQL
az provider show --namespace Microsoft.Web --query registrationState --output tsv
az provider show --namespace Microsoft.Storage --query registrationState --output tsv
az provider show --namespace Microsoft.DBforPostgreSQL --query registrationState --output tsv
```

Wait until all three `show` commands return `Registered`. Registration can take a few minutes.

## 3. Choose and validate deployment names

Choose a region close to your users, such as `centralindia`, `eastus`, or `westeurope`. The resource group may use letters, numbers, periods, underscores, parentheses, and hyphens. The storage account, Function App, and PostgreSQL server names must be globally unique.

For the three globally unique names, use lowercase letters, numbers, and hyphens where allowed; the storage account must contain **only** lowercase letters and numbers (3-24 characters). The Function App and PostgreSQL server names should be globally unique and lowercase. Do not reuse the example values below without changing their suffix.

Set the values for this deployment. Replace every value marked with `CHANGE-ME`:

```powershell
Set-Location E:\Project\ezest\AzureReactCrudDemo

$resourceGroup = 'rg-azure-react-crud-dev'
$location = 'centralindia'
$storageAccount = 'azreactcruddev12345'       # lowercase letters/numbers, globally unique
$functionApp = 'azreactcrud-api-dev-12345'    # globally unique
$postgresServer = 'azreactcrud-pg-dev-12345'  # globally unique
$postgresDb = 'cruddb'
$postgresUser = 'pgadmin'
$postgresPassword = 'CHANGE-ME-use-a-long-unique-password'
```

Use a password manager to create and retain the PostgreSQL administrator password. Do not put a real password into a committed script, source file, terminal transcript, or shared chat. The command history can retain literal passwords; clear or protect that history according to your organization's policy.

Check name availability before deploying:

```powershell
az storage account check-name --name $storageAccount --query nameAvailable --output tsv
az functionapp check-name-availability --name $functionApp --query nameAvailable --output tsv
az postgres flexible-server check-name-availability --name $postgresServer --query nameAvailable --output tsv
```

Each command must return `true`. If it does not, alter the relevant name and repeat this step.

## 4. Review what the script will create

The deployment script creates these Azure resources in the resource group:

- A StorageV2 account (`Standard_LRS`) with static website hosting enabled. It hosts the React single-page app from its `$web` container.
- An Azure Database for PostgreSQL Flexible Server (Burstable `Standard_B1ms`) and the `cruddb` database.
- A firewall rule permitting only the public IP from which the script runs, so it can import the schema.
- A Consumption-plan Azure Function App using .NET isolated worker and Functions v4.
- A Function App setting named `ConnectionStrings__Postgres`, containing the PostgreSQL connection string with TLS required.
- A Function CORS rule that allows the Storage static website origin.

The script then publishes the .NET Function, deploys it as a ZIP package, builds the React application with the deployed Function URL, and uploads `frontend/dist` to the `$web` container.

## 5. Run the deployment script

Keep the PowerShell window open in the repository root, where the variables from Step 3 are defined. Run:

```powershell
.\infrastructure\deploy.ps1 `
  -ResourceGroup $resourceGroup `
  -Location $location `
  -StorageAccount $storageAccount `
  -FunctionApp $functionApp `
  -PostgresServer $postgresServer `
  -PostgresDb $postgresDb `
  -PostgresUser $postgresUser `
  -PostgresPassword $postgresPassword
```

The first deployment can take several minutes. Do not close the window while it is running. The script ends by printing two URLs:

- `React site`: the public static website URL
- `Function API`: the products endpoint URL

Save those URLs. A successful command exits without a PowerShell error.

If PowerShell blocks local scripts because of its execution policy, run the script for this session only, then rerun the command above:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## 6. Verify Azure resources and Function configuration

Run these commands after the script succeeds:

```powershell
az group show --name $resourceGroup --output table
az resource list --resource-group $resourceGroup --output table
az functionapp show --name $functionApp --resource-group $resourceGroup --query state --output tsv
az functionapp function list --name $functionApp --resource-group $resourceGroup --output table
az storage account show --name $storageAccount --resource-group $resourceGroup --query primaryEndpoints.web --output tsv
```

Expected results:

- The Function App state is `Running`.
- The function list contains the product HTTP endpoints.
- The final command returns the same static website URL printed by the script.

Do **not** print the Function App's application settings, because the database password is stored there. You can safely verify that the setting exists without revealing its value:

```powershell
az functionapp config appsettings list --name $functionApp --resource-group $resourceGroup --query "[?name=='ConnectionStrings__Postgres'].name" --output tsv
```

It must return `ConnectionStrings__Postgres`.

## 7. Confirm the database schema was loaded

When `psql` was installed, the script loads `database/schema.sql` automatically. Confirm that the table and seed data exist:

```powershell
$env:PGPASSWORD = $postgresPassword
psql "host=$postgresServer.postgres.database.azure.com port=5432 dbname=$postgresDb user=$postgresUser sslmode=require" -c "SELECT id, name, price FROM products ORDER BY id;"
Remove-Item Env:PGPASSWORD
```

The output should show `Laptop`, `Mouse`, and `Keyboard`.

If the script warned that `psql` was unavailable, install the PostgreSQL client, then run this import exactly once:

```powershell
$env:PGPASSWORD = $postgresPassword
psql "host=$postgresServer.postgres.database.azure.com port=5432 dbname=$postgresDb user=$postgresUser sslmode=require" -f .\database\schema.sql
Remove-Item Env:PGPASSWORD
```

If the connection is rejected, get your current public IP and add it to the PostgreSQL firewall. The deployment script normally creates this rule automatically:

```powershell
$myIp = (Invoke-RestMethod -Uri 'https://api.ipify.org')
az postgres flexible-server firewall-rule create `
  --resource-group $resourceGroup `
  --name $postgresServer `
  --rule-name AllowMyCurrentIp `
  --start-ip-address $myIp `
  --end-ip-address $myIp
```

## 8. Test the deployed API

Use the deployed endpoint. The API URL must use HTTPS:

```powershell
$apiUrl = "https://$functionApp.azurewebsites.net/api/products"
Invoke-RestMethod -Uri $apiUrl
```

The request should return the seed products as JSON. Test a full create/read/delete cycle:

```powershell
$newProduct = @{ name = 'Azure deployment test'; description = 'Temporary verification record'; price = 1.00 } | ConvertTo-Json
$created = Invoke-RestMethod -Method Post -Uri $apiUrl -ContentType 'application/json' -Body $newProduct
$created
Invoke-RestMethod -Uri "$apiUrl/$($created.id)"
Invoke-RestMethod -Method Delete -Uri "$apiUrl/$($created.id)"
```

The delete call has no response body when successful. The temporary record should no longer be returned by `GET $apiUrl`.

## 9. Test the deployed website

Open the static website URL printed in Step 5, or retrieve it again:

```powershell
$siteUrl = az storage account show --name $storageAccount --resource-group $resourceGroup --query primaryEndpoints.web --output tsv
Start-Process $siteUrl
```

In the browser:

1. Confirm the initial product list loads.
2. Add a product.
3. Edit the new product and save it.
4. Refresh the page and confirm the edit persisted.
5. Delete the test product.

If the UI loads but cannot read products, open browser developer tools and check the Network and Console panels. Verify the Function API in Step 8 works and that the Function App CORS rule includes the exact static website origin. You can list it with:

```powershell
az functionapp cors show --name $functionApp --resource-group $resourceGroup
```

## 10. Redeploy after code changes

For normal application-code changes, retain the same values from Step 3 and rerun the command in Step 5. The script rebuilds and redeploys both backend and frontend.

Do not rerun the full provisioning script with changed resource names unless you intend to create a separate environment. For database changes, apply a reviewed migration or SQL script deliberately before deploying code that depends on it. `database/schema.sql` uses `CREATE TABLE IF NOT EXISTS`, so it will not modify an existing table structure.

## Troubleshooting

| Problem | Check and resolution |
| --- | --- |
| Resource name unavailable | Change the storage account, Function App, or PostgreSQL server name, then rerun Step 3. |
| Azure CLI says a provider is not registered | Complete Step 2 and wait for `Registered`. |
| `psql` cannot connect | Ensure your current public IP is permitted by the PostgreSQL firewall and use `sslmode=require`. Re-run the firewall command in Step 7 if your IP changed. |
| Schema missing or API returns a database-table error | Complete Step 7, then call the API again. |
| Function API returns 5xx | Inspect Function App logs in the Azure portal and verify the `ConnectionStrings__Postgres` setting exists. Do not expose its value in logs. |
| Website shows a CORS error | Run `az functionapp cors show`, then ensure the allowed origin exactly matches the Storage static website endpoint. |
| Website uses a local API address | The frontend must be rebuilt with `VITE_API_BASE_URL=https://<function-app>.azurewebsites.net/api`; the supplied script does this automatically. |
| Static site shows 404 after a client-side route | Confirm the static website has `index.html` configured as its error document; the script configures this. |

## Production hardening

Before a production release, change this development setup to use:

- Azure Key Vault and managed identity for database secrets; do not keep the PostgreSQL password in a Function App setting.
- Private networking: VNet integration and a private endpoint for PostgreSQL; remove public database access and broad firewall rules.
- Microsoft Entra ID or another authentication/authorization layer for the API.
- Application Insights, alert rules, backup/restore validation, least-privilege database roles, and a defined retention policy.
- CI/CD with separate dev, test, and production resource groups, reviewed database migrations, and no secrets in source control or build logs.
- A custom domain, HTTPS enforcement, and an edge security layer such as Front Door/WAF when applicable.

## Delete the deployment when it is no longer needed

Deleting the resource group removes the Function App, storage website, PostgreSQL server/database, logs, and their data. Verify the target first:

```powershell
az group show --name $resourceGroup --output table
```

When you are certain, delete it:

```powershell
az group delete --name $resourceGroup --yes --no-wait
```

Check completion later:

```powershell
az group exists --name $resourceGroup
```

It returns `false` once deletion is complete. This action is not recoverable unless you have independent backups.
