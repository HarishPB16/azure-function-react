# Deploy the React frontend to Azure Blob Storage

Follow these steps to deploy **only the React/Vite frontend** in `frontend/` to Azure Blob Storage static website hosting.

```text
React/Vite source -> npm production build -> Azure Blob Storage ($web container) -> Browser
```

The React app calls the API URL supplied through `VITE_API_BASE_URL` when it is built. For this repository, use your deployed Azure Function API URL, for example `https://<function-app>.azurewebsites.net/api`.

> Important: Vite compiles `VITE_API_BASE_URL` into the JavaScript files during `npm run build`. Changing an Azure Storage setting later does not update the API URL. Build and upload the site again whenever the API URL changes.

## Step 1: Prerequisites

1. Sign in to [Azure portal](https://portal.azure.com) and confirm you have an active subscription with permission to create a resource group and Storage account.
2. Install [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli-windows) and Node.js LTS.
3. Open PowerShell in the repository root:

   ```powershell
   Set-Location E:\Project\ezest\AzureReactCrudDemo
   ```

4. Confirm the required tools are installed:

   ```powershell
   az version
   node --version
   npm --version
   ```

**Check:** Every command returns a version.

## Step 2: Build the React app locally

1. Set the deployed API URL. Replace the placeholder with your Azure Function App URL; keep `/api` at the end.

   ```powershell
   $apiUrl = 'https://YOUR-FUNCTION-APP.azurewebsites.net/api'
   ```

2. Install the exact package versions and create a production build:

   ```powershell
   Set-Location .\frontend
   npm ci
   $env:VITE_API_BASE_URL = $apiUrl
   npm run build
   Set-Location ..
   ```

3. Confirm the build output exists:

   ```powershell
   Get-ChildItem .\frontend\dist
   ```

**Check:** The `frontend/dist` folder contains `index.html` and an `assets` folder.

## Step 3: Sign in to Azure and select the subscription

1. Sign in:

   ```powershell
   az login
   ```

2. List subscriptions and select the one that should be billed:

   ```powershell
   az account list --output table
   az account set --subscription 'YOUR-SUBSCRIPTION-NAME-OR-ID'
   az account show --output table
   ```

3. Register the Storage resource provider (safe to run again):

   ```powershell
   az provider register --namespace Microsoft.Storage
   az provider show --namespace Microsoft.Storage --query registrationState --output tsv
   ```

**Check:** `az account show` displays the intended subscription and the provider state is `Registered`.

## Step 4: Choose the resource names

1. Copy this block into the same PowerShell window. Change the values marked `CHANGE-ME`.

   ```powershell
   $resourceGroup = 'rg-react-blob-dev'
   $location = 'centralindia'
   $storageAccount = 'CHANGEMEreactblob12345' # 3-24 lowercase letters/numbers only; globally unique
   ```

2. Confirm the Storage account name is available:

   ```powershell
   az storage account check-name --name $storageAccount --query nameAvailable --output tsv
   ```

**Check:** The command returns `true`. If it returns `false`, choose another name and repeat the check.

## Step 5: Create the Storage account and enable static website hosting

1. Create the resource group:

   ```powershell
   az group create --name $resourceGroup --location $location
   ```

2. Create a standard locally redundant Storage account:

   ```powershell
   az storage account create --name $storageAccount --resource-group $resourceGroup --location $location --sku Standard_LRS --kind StorageV2
   ```

3. Retrieve an account key for this deployment session. Do not commit or share this value:

   ```powershell
   $storageKey = az storage account keys list --resource-group $resourceGroup --account-name $storageAccount --query '[0].value' --output tsv
   ```

4. Enable the Static Website feature. `index.html` is both the main page and the fallback page for client-side routes:

   ```powershell
   az storage blob service-properties update --account-name $storageAccount --account-key $storageKey --static-website --index-document index.html --404-document index.html
   ```

5. Get the website URL:

   ```powershell
   $siteUrl = az storage account show --name $storageAccount --resource-group $resourceGroup --query primaryEndpoints.web --output tsv
   $siteUrl
   ```

**Check:** The URL ends in `/` and normally resembles `https://<storage-account>.z##.web.core.windows.net/`.

## Step 6: Upload the React build to the `$web` Blob container

1. Upload all compiled frontend files:

   ```powershell
   az storage blob upload-batch --account-name $storageAccount --account-key $storageKey --destination '$web' --source .\frontend\dist --overwrite
   ```

2. Open the deployed website:

   ```powershell
   Start-Process $siteUrl
   ```

3. In the browser, confirm the product list loads. Create, edit, and delete a temporary product.

**Check:** The application works through the Azure Blob Storage website URL.

### Optional: build and upload with the supplied Docker files

The repository Docker configuration builds the React site and uploads it to Blob Storage from a single container. It does not use Nginx, ACR, or Azure Web App.

1. Install and start Docker Desktop.
2. Set the API URL and the Storage account credentials in the same PowerShell window:

   ```powershell
   $env:VITE_API_BASE_URL = $apiUrl
   $env:AZURE_STORAGE_ACCOUNT = $storageAccount
   $env:AZURE_STORAGE_KEY = $storageKey
   ```

3. Build and run the deployment container:

   ```powershell
   docker compose run --rm deploy-blob
   ```

**Check:** Docker reports that the files were uploaded to `$web`. Open `$siteUrl` and hard-refresh with `Ctrl+F5`.

## Step 7: Configure Function App CORS

If the site opens but product requests fail with a CORS error, allow the exact Blob Storage website origin in the Azure Function App. Replace the placeholders with the Function App details:

```powershell
$functionApp = 'YOUR-FUNCTION-APP-NAME'
$functionResourceGroup = 'YOUR-FUNCTION-RESOURCE-GROUP'
az functionapp cors add --name $functionApp --resource-group $functionResourceGroup --allowed-origins $siteUrl
az functionapp restart --name $functionApp --resource-group $functionResourceGroup
```

**Check:** Refresh the website, then confirm product operations work. Do not use `*` as a production CORS origin.

## Step 8: Deploy later frontend changes

1. Update the React code.
2. In the repository root, set the API URL, rebuild, and upload again:

   ```powershell
   $env:VITE_API_BASE_URL = $apiUrl
   Push-Location .\frontend
   npm ci
   npm run build
   Pop-Location

   az storage blob upload-batch --account-name $storageAccount --account-key $storageKey --destination '$web' --source .\frontend\dist --overwrite
   ```

3. Hard-refresh the browser with `Ctrl+F5`.

**Check:** The latest change is visible. If it is not, wait a minute and hard-refresh again; browsers can cache JavaScript files.

## Troubleshooting

| Problem | Resolution |
| --- | --- |
| `az` or `npm` is not recognized | Close and reopen PowerShell. If it still fails, repair the Azure CLI or Node.js installation. |
| Storage account name unavailable | Change `$storageAccount`; the name must be globally unique and use only lowercase letters and numbers. |
| `npm run build` fails | Fix the reported React or TypeScript error before uploading. Run the command from `frontend`. |
| Docker Compose says an Azure Storage variable is missing | Set `AZURE_STORAGE_ACCOUNT` and `AZURE_STORAGE_KEY` in the same PowerShell window before running the Docker command. |
| Website returns 404 | Confirm Static Website hosting is enabled and `index.html` is configured as both index and error document in Step 5. |
| UI calls `localhost:7071` | Rebuild after setting `$env:VITE_API_BASE_URL = $apiUrl`, then repeat the upload command. |
| Website shows a CORS error | Complete Step 7 with the exact `$siteUrl` origin. |
| A changed file is not visible | Repeat the upload command and hard-refresh the browser with `Ctrl+F5`. |

## Optional cleanup

Deleting the resource group permanently removes the Storage account and every uploaded Blob. Confirm the exact target first:

```powershell
az group show --name $resourceGroup --output table
```

Only when you are certain this is the correct non-production resource group, delete it:

```powershell
az group delete --name $resourceGroup --yes --no-wait
```
