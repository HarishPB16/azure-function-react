# Step-by-step Azure deployment (follow this document)

Use this document to deploy **this repository** from your Windows machine to Azure. Do each numbered step in order and do not move to the next step until the stated **Check** passes.

This project deploys three parts:

```text
Browser
  -> React frontend in Azure Storage static website
  -> .NET 8 API in Azure Function App
  -> Azure Database for PostgreSQL Flexible Server
```

The repository already contains an automated deployment script: `infrastructure/deploy.ps1`. You will configure the prerequisites, run that script, and verify every deployed component.

> Important: this is a development deployment. It uses public PostgreSQL networking and a password-based database connection. It is suitable for learning/testing, but follow the production checklist at the end before using it with real customer data.

---

## Step 0 — Understand what Azure will create and charge for

The deployment creates a single resource group containing:

| Azure resource | Why it is needed | Created by |
| --- | --- | --- |
| Resource group | Container for all resources | Deployment script |
| Storage account (StorageV2, Standard_LRS) | Hosts the React website | Deployment script |
| Static website (`$web` container) | Serves `index.html`, JavaScript, CSS, and assets | Deployment script |
| Function App (Consumption plan) | Runs the .NET 8 REST API | Deployment script |
| PostgreSQL Flexible Server (Burstable `Standard_B1ms`) | Stores products | Deployment script |
| PostgreSQL database `cruddb` | Application database | Deployment script |
| PostgreSQL firewall rules | Allow Azure-hosted Function traffic and your current public IP for schema/query work | Deployment script |

Azure services cost money depending on your subscription, region, usage, and retention settings. Check the Azure portal's **Cost Management + Billing** area before deployment. Delete the resource group using Step 15 when you no longer need it.

---

## Step 1 — Create or confirm your Azure subscription and permissions

1. Go to [Azure portal](https://portal.azure.com) and sign in with the Microsoft account that owns or can use the Azure subscription.
2. Search for **Subscriptions** and open the subscription you will use.
3. Confirm the subscription status is **Enabled**.
4. Open **Access control (IAM)** for that subscription.
5. Confirm your account has at least the **Contributor** role. If you cannot view/create resource groups, ask the subscription owner to assign that role (or a more restricted role that permits the required resources).
6. Note the subscription name or subscription ID. You will use it in Step 4.

**Check:** You can see your subscription in the portal and know its name or ID.

---

## Step 2 — Install the local tools

Open PowerShell **as Administrator**. Install the tools below if they are not already installed. After installing, close every PowerShell window and open a new standard PowerShell window.

### 2.1 Azure CLI

```powershell
winget install Microsoft.AzureCLI
```

### 2.2 Node.js LTS (the React build)

```powershell
winget install OpenJS.NodeJS.LTS
```

### 2.3 .NET 8 SDK (the Azure Function build)

```powershell
winget install Microsoft.DotNet.SDK.8
```

### 2.4 PostgreSQL client tools (`psql`)

Install PostgreSQL using the installer from [postgresql.org/download/windows](https://www.postgresql.org/download/windows/). During installation, keep **Command Line Tools** selected. Add PostgreSQL's `bin` folder to your Windows `Path` if the installer does not do so. A typical folder is `C:\Program Files\PostgreSQL\16\bin`.

`psql` is needed because the deployment script uses it to create the table and seed data. If you skip it, you will need to install it and complete Step 9 manually before the deployed app can work.

### 2.5 Verify all tools

In the new PowerShell window, run:

```powershell
az version
node --version
npm --version
dotnet --version
psql --version
```

**Check:** Every command returns a version. `dotnet --version` must begin with `8.`. If a command is not recognized, close/reopen PowerShell; then repair the installation or update `Path` before continuing.

---

## Step 3 — Confirm the project builds locally

This prevents confusing Azure errors caused by an application that does not compile.

```powershell
Set-Location E:\Project\ezest\AzureReactCrudDemo

Set-Location .\frontend
npm ci
npm run build

Set-Location ..\backend\AzureReactCrudFunction
dotnet restore
dotnet build --configuration Release

Set-Location ..\..
```

Do not upload `frontend/dist`, `backend/**/bin`, or `backend/**/obj` manually. The deployment script rebuilds and deploys them.

**Check:** `npm run build` and `dotnet build --configuration Release` both complete with no errors.

---

## Step 4 — Sign in to Azure CLI and select exactly one subscription

From the project directory, sign in:

```powershell
az login
```

A browser window opens. Complete sign-in, then return to PowerShell. List the subscriptions available to this account:

```powershell
az account list --output table
```

Set the target subscription. Replace the placeholder with the name or ID noted in Step 1:

```powershell
az account set --subscription "REPLACE-WITH-YOUR-SUBSCRIPTION-NAME-OR-ID"
az account show --output table
```

**Check:** The output of `az account show` displays the intended subscription. Stop here if it is the wrong subscription—deploying to the wrong one can create unexpected cost.

---

## Step 5 — Register the Azure resource providers

Run the following once for the selected subscription. It is safe to run them again:

```powershell
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.DBforPostgreSQL
```

Now check the registration state:

```powershell
az provider show --namespace Microsoft.Web --query registrationState --output tsv
az provider show --namespace Microsoft.Storage --query registrationState --output tsv
az provider show --namespace Microsoft.DBforPostgreSQL --query registrationState --output tsv
```

Provider registration can take a few minutes.

**Check:** All three commands return `Registered`. Do not continue while any shows `Registering` or `NotRegistered`.

---

## Step 6 — Select the deployment names, region, and database credentials

You need globally unique names for the Storage account, Function App, and PostgreSQL server. Add your name, company abbreviation, and random digits to make them unique.

Rules:

- Storage account: 3-24 characters; **lowercase letters and numbers only**; globally unique.
- Function App: globally unique; use lowercase letters, numbers, and hyphens.
- PostgreSQL server: globally unique; use lowercase letters, numbers, and hyphens.
- Region: use an Azure region that supports the resources you need and is close to your users, for example `centralindia`, `eastus`, or `westeurope`.
- Database password: use a new, strong password stored in a password manager. Do not reuse a personal password.

Copy this whole block into PowerShell, then replace the values. Do **not** use `CHANGE-ME` unchanged:

```powershell
Set-Location E:\Project\ezest\AzureReactCrudDemo

$resourceGroup = 'rg-azure-react-crud-dev'
$location = 'centralindia'
$storageAccount = 'CHANGE-ME12345'       # lowercase letters/numbers only
$functionApp = 'change-me-api-12345'
$postgresServer = 'change-me-pg-12345'
$postgresDb = 'cruddb'
$postgresUser = 'pgadmin'
$postgresPassword = 'CHANGE-ME-create-a-strong-unique-password'
```

The password is passed to the script and may be stored in your PowerShell command history. Do not paste a real password in a shared screen recording, chat, or committed file. Use a private terminal and protect/delete terminal history according to your organization's policy.

Check that your three globally-unique names are unused:

```powershell
az storage account check-name --name $storageAccount --query nameAvailable --output tsv
az functionapp check-name-availability --name $functionApp --query nameAvailable --output tsv
az postgres flexible-server check-name-availability --name $postgresServer --query nameAvailable --output tsv
```

**Check:** Each command returns `true`. If any returns `false`, edit that variable and repeat all three checks.

---

## Step 7 — Run the automated Azure deployment

Make sure you are in `E:\Project\ezest\AzureReactCrudDemo` and that the variables from Step 6 still exist in the **same PowerShell window**. Then run:

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

What the script does, in this order:

1. Creates the resource group.
2. Creates the Storage account and enables static website hosting with `index.html` as both the index and error document.
3. Creates the PostgreSQL Flexible Server with public networking enabled for Azure services, then creates the `cruddb` database.
4. Gets your current public IP address and creates a second firewall rule for that IP.
5. Runs `database/schema.sql` through `psql` to create the `products` table and seed products.
6. Creates the .NET 8 isolated Azure Function App on a Consumption plan.
7. Stores `ConnectionStrings__Postgres` in the Function App and enables HTTPS/TLS database access using `SSL Mode=Require`.
8. Adds CORS permission for the Storage static website origin only.
9. Publishes the .NET Function, creates a ZIP file, and deploys it to the Function App.
10. Builds the React frontend with `VITE_API_BASE_URL` pointing at the newly deployed Function App.
11. Uploads `frontend/dist` to the Storage account's `$web` container.
12. Prints the website URL and API URL.

If PowerShell reports that scripts are disabled, run this command (only affects the current PowerShell window), then repeat Step 7:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

**Check:** The script finishes without an error and prints both `React site:` and `Function API:` URLs. Copy both URLs into a secure note.

---

## Step 8 — Verify the Azure resources were created

Run these commands in the same PowerShell window:

```powershell
az group show --name $resourceGroup --output table
az resource list --resource-group $resourceGroup --output table
az functionapp show --name $functionApp --resource-group $resourceGroup --query state --output tsv
az functionapp function list --name $functionApp --resource-group $resourceGroup --output table
az storage account show --name $storageAccount --resource-group $resourceGroup --query primaryEndpoints.web --output tsv
```

**Check:**

- The resource group exists.
- The resource list includes a Storage account, Function App, and PostgreSQL flexible server.
- Function state is `Running`.
- The Function list contains the products HTTP functions.
- The final command returns a website URL ending with `/`.

Verify that the Function App has the required setting without exposing the secret value:

```powershell
az functionapp config appsettings list `
  --name $functionApp `
  --resource-group $resourceGroup `
  --query "[?name=='ConnectionStrings__Postgres'].name" `
  --output tsv
```

**Check:** It returns exactly `ConnectionStrings__Postgres`. Never run this command without the `--query` filter or share its output because the connection string contains the database password.

---

## Step 9 — Verify the PostgreSQL table and seed records

The script does this automatically when `psql` was installed. Check it explicitly:

```powershell
$env:PGPASSWORD = $postgresPassword
psql "host=$postgresServer.postgres.database.azure.com port=5432 dbname=$postgresDb user=$postgresUser sslmode=require" -c "SELECT id, name, price FROM products ORDER BY id;"
Remove-Item Env:PGPASSWORD
```

**Check:** You see `Laptop`, `Mouse`, and `Keyboard`.

### If the table does not exist or `psql` was missing in Step 7

After installing `psql`, import the schema:

```powershell
$env:PGPASSWORD = $postgresPassword
psql "host=$postgresServer.postgres.database.azure.com port=5432 dbname=$postgresDb user=$postgresUser sslmode=require" -f .\database\schema.sql
Remove-Item Env:PGPASSWORD
```

If you receive a firewall or timeout error, add your current public IP address and retry. This is needed if your ISP/VPN IP changed since deployment:

```powershell
$myIp = Invoke-RestMethod -Uri 'https://api.ipify.org'
az postgres flexible-server firewall-rule create `
  --resource-group $resourceGroup `
  --server-name $postgresServer `
  --rule-name AllowMyCurrentIp `
  --start-ip-address $myIp `
  --end-ip-address $myIp
```

Wait a few minutes after changing a firewall rule before retrying the connection.

---

## Step 10 — Test the deployed Function API

Create an API URL variable and list the products:

```powershell
$apiUrl = "https://$functionApp.azurewebsites.net/api/products"
Invoke-RestMethod -Uri $apiUrl
```

**Check:** The result is a JSON list containing the seed products.

Test every API operation with a temporary record:

```powershell
$testProduct = @{ name = 'Deployment test'; description = 'Temporary Azure test record'; price = 1.00 } | ConvertTo-Json
$created = Invoke-RestMethod -Method Post -Uri $apiUrl -ContentType 'application/json' -Body $testProduct
$created

Invoke-RestMethod -Uri "$apiUrl/$($created.id)"

$updatedProduct = @{ name = 'Deployment test updated'; description = 'Updated temporary record'; price = 2.00 } | ConvertTo-Json
Invoke-RestMethod -Method Put -Uri "$apiUrl/$($created.id)" -ContentType 'application/json' -Body $updatedProduct

Invoke-RestMethod -Method Delete -Uri "$apiUrl/$($created.id)"
```

**Check:** Create returns an object with an `id`, read/update work, and delete completes without an error. The temporary record is deleted at the end.

---

## Step 11 — Test the deployed React website

Get and open the frontend URL:

```powershell
$siteUrl = az storage account show --name $storageAccount --resource-group $resourceGroup --query primaryEndpoints.web --output tsv
Start-Process $siteUrl
```

In the browser, do all of the following:

1. Confirm the product table loads.
2. Click **Add product** and create a product.
3. Edit that product and save it.
4. Refresh the browser page. Confirm the changed record remains.
5. Delete the test product.
6. Refresh again. Confirm it is gone.

**Check:** All create, edit, refresh, and delete actions work without browser console errors.

If the website appears but API calls fail with a CORS error, check the allowed origins:

```powershell
az functionapp cors show --name $functionApp --resource-group $resourceGroup
```

The allowed origin must be the exact Storage static website origin. If you need to add it again:

```powershell
az functionapp cors add --name $functionApp --resource-group $resourceGroup --allowed-origins $siteUrl
```

---

## Step 12 — Deploy later code changes

For frontend or backend source-code changes:

1. Make and test your changes locally.
2. Re-open PowerShell and complete Steps 4 and 6 again to set your Azure subscription and variables.
3. Run the Step 7 deployment command using the **same resource names**.
4. Repeat Steps 8, 10, and 11.

Do not change the resource names when updating the same environment. Changed names create new Azure resources instead of updating the existing ones.

For database schema changes, create a reviewed migration SQL file and run it intentionally against the Azure database before deploying code that requires the new schema. Do not rely on `database/schema.sql` to alter existing tables: it only creates the table if absent.

---

## Step 13 — Common errors and exact fixes

| Error or symptom | Fix |
| --- | --- |
| `az` / `node` / `dotnet` / `psql` is not recognized | Close and reopen PowerShell. If still missing, repair the installation and ensure its install folder is in `Path`. |
| `SubscriptionNotFound` or wrong subscription | Run `az account list --output table`, then repeat `az account set --subscription "..."`. |
| `MissingSubscriptionRegistration` | Repeat Step 5 and wait for all providers to become `Registered`. |
| Storage/Function/PostgreSQL name unavailable | Change only the unavailable name in Step 6, then repeat the three availability checks. |
| PostgreSQL connection timed out / firewall rejected it | Run the current-IP firewall command in Step 9. Confirm your VPN has not changed your IP. |
| API returns 500 or mentions `products` | Complete the schema import in Step 9; then test Step 10 again. |
| API returns 500 after schema exists | Confirm the Function setting exists in Step 8. Use Azure portal **Function App → Monitoring → Log stream** to inspect errors; do not publish the connection string. |
| UI shows a CORS error | Run the CORS checks/repair command at the end of Step 11, then hard-refresh the browser. |
| UI calls `localhost:7071` after deployment | Re-run Step 7. It rebuilds React with the Azure Function URL; uploading an old local `dist` folder will keep the wrong URL. |
| Script stops at `psql` | Correct the PostgreSQL password/firewall issue, or finish deployment then complete Step 9 manually. |

---

## Step 14 — What to do before production

Do not treat the development deployment as production-ready. Before exposing it to real users, complete these changes:

1. Create separate resource groups and separate databases for `dev`, `staging`, and `prod`. Never point a dev Function App at the production database.
2. Use Azure Key Vault and managed identity so the database secret is not stored in Function App settings or PowerShell history.
3. Use PostgreSQL private access (VNet integration/private endpoint) and remove public database access/firewall rules.
4. Create a limited database role for the application instead of using the PostgreSQL administrator account.
5. Add authentication and authorization to API endpoints before storing user data.
6. Enable Application Insights, alerts, backups, restore testing, and cost budgets.
7. Use a custom domain with HTTPS, and consider Front Door/WAF for an internet-facing application.
8. Set up CI/CD with separate environment secrets and protected release approvals; never commit `.env`, `local.settings.json`, database passwords, or deployment credentials.
9. Test database migrations and a full restore procedure before every production schema change.

---

## Step 15 — Delete Azure resources when finished (optional but important)

Deleting the resource group permanently removes the Function App, website files, PostgreSQL server/database, and their data. First verify the exact target:

```powershell
az group show --name $resourceGroup --output table
```

When you are certain this is the correct non-production resource group, delete it:

```powershell
az group delete --name $resourceGroup --yes --no-wait
```

Check whether deletion has completed:

```powershell
az group exists --name $resourceGroup
```

**Check:** It returns `false` when deletion is complete. Deletion cannot be undone unless you have independent backups.
